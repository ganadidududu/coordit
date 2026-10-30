package com.inseong.coordit.ui.closet

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.inseong.coordit.data.closet.*
import com.inseong.coordit.data.repository.SessionRepository
import java.util.UUID
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch

class ClosetViewModel(private val repository: ClosetRepository, private val sessions: SessionRepository, private val homeRepository: com.inseong.coordit.data.home.HomeRepository? = null) : ViewModel() {
    private val mutableState = MutableStateFlow(ClosetState())
    val state = mutableState.asStateFlow()
    private var work: Job? = null
    private var generation = 0L
    private var pendingKey: String? = null
    private var owner = sessions.session.value?.user?.id
    private var beforeExample: ClosetState? = null
    private var beforeExampleKey: String? = null
    private var beforeExampleRegistration = false
    private var registeringForFitLab = false
    init {
        viewModelScope.launch {
            sessions.session.map { it?.user?.id }.distinctUntilChanged().collect { id ->
                if (owner != id) {
                    generation++; work?.cancel(); owner = id; pendingKey = null; beforeExample = null; beforeExampleKey = null; beforeExampleRegistration = false; registeringForFitLab = false
                    mutableState.value = ClosetState()
                }
            }
        }
    }
    suspend fun inferGarment(bitmap: android.graphics.Bitmap, category: String): com.inseong.coordit.data.fitlab.camera.GarmentLandmarkClient.Outcome {
        val client = com.inseong.coordit.data.fitlab.camera.GarmentLandmarkClient()
        val session = sessions.session.value ?: return com.inseong.coordit.data.fitlab.camera.GarmentLandmarkClient.Outcome.Fallback("login_required")
        val endpoint = com.inseong.coordit.BuildConfig.API_BASE_URL.trimEnd('/') + "/garment-landmarks"
        val result = client.infer(com.inseong.coordit.data.fitlab.camera.GarmentLandmarkClient.Input(bitmap, category, endpoint, session.accessToken, true))
        return if (sessions.session.value?.user?.id == session.user.id) result
        else com.inseong.coordit.data.fitlab.camera.GarmentLandmarkClient.Outcome.Fallback("session_changed")
    }

    private fun runOperation(block: suspend (String, Long) -> Unit) {
        if (state.value.busy) return
        val session = sessions.session.value ?: run { mutableState.value = state.value.copy(loading = false, error = "로그인이 필요해요."); return }
        val ticket = ++generation
        work?.cancel()
        mutableState.value = state.value.copy(busy = true, error = null)
        work = viewModelScope.launch {
            try { block(session.accessToken, ticket) }
            catch (failure: Exception) {
                if (failure is CancellationException) throw failure
                if (current(ticket)) mutableState.value = state.value.copy(error = if (failure is IllegalArgumentException) failure.message else "요청을 완료하지 못했어요. 다시 시도해 주세요.")
            } finally { if (current(ticket)) mutableState.value = state.value.copy(busy = false, loading = false) }
        }
    }
    private fun current(ticket: Long) = ticket == generation && sessions.session.value?.user?.id == owner && owner != null
    fun error(message: String) { mutableState.value = state.value.copy(error = message) }
    fun load() {
        if (state.value.busy) return
        mutableState.value = state.value.copy(loading = true)
        runOperation { token, ticket ->
            val items = repository.load(token)
            if (current(ticket)) mutableState.value = state.value.copy(items = items)
            refreshProfiles(token, ticket)
        }
    }
    private suspend fun refreshProfiles(token: String, ticket: Long) {
        for (upper in listOf(true, false)) {
            if (!current(ticket)) return
            try {
                val profile = repository.profile(token, upper)
                if (current(ticket)) mutableState.value = state.value.copy(profiles = state.value.profiles + (upper to profile))
            } catch (failure: Exception) {
                if (failure is CancellationException) throw failure
                if (current(ticket)) error("기준 핏 정보를 불러오지 못했어요. 다시 시도해 주세요.")
            }
        }
    }
    fun startAdd() {
        if (state.value.busy) return
        registeringForFitLab = false
        pendingKey = null
        mutableState.value = state.value.copy(screen = ClosetScreen.Method, draft = ClosetDraft(), error = null)
    }
    fun startReferenceRegistration() {
        if (state.value.busy) return
        startAdd()
        registeringForFitLab = true
        chooseMethod(ClosetMethod.Link)
    }
    fun beginExample(): Boolean {
        if (state.value.busy) return false
        if (!state.value.draft.isExample) {
            beforeExample = state.value
            beforeExampleKey = pendingKey
            beforeExampleRegistration = registeringForFitLab
        }
        mutableState.value = state.value.copy(screen = ClosetScreen.Link, detail = null, error = null,
            draft = ClosetDraft(method = ClosetMethod.Link, productLink = com.inseong.coordit.data.fitlab.FitLabExample.link, isExample = true))
        return true
    }
    fun finishExample() {
        if (!state.value.draft.isExample) return
        mutableState.value = beforeExample ?: ClosetState()
        pendingKey = beforeExampleKey
        registeringForFitLab = beforeExampleRegistration
        beforeExample = null
        beforeExampleKey = null
        beforeExampleRegistration = false
    }
    fun chooseMethod(method: ClosetMethod) {
        if (state.value.busy) return
        editDraft { if (it.method != method) it.copy(method = method, sizeRows = emptyList(), selectedSizeRowId = null) else it }
        mutableState.value = state.value.copy(screen = screenFor(method), error = null)
    }
    fun editDraft(edit: (ClosetDraft) -> ClosetDraft) {
        if (state.value.busy) return
        val previous = state.value.draft
        val proposed = edit(previous)
        val changedMeasurements = proposed.category != previous.category || proposed.method != previous.method ||
            listOf(proposed.measurement1, proposed.measurement2, proposed.measurement3, proposed.measurement4) !=
            listOf(previous.measurement1, previous.measurement2, previous.measurement3, previous.measurement4)
        val edited = if (changedMeasurements && proposed.cameraMetadata == previous.cameraMetadata)
            proposed.copy(cameraMetadata = emptyMap()) else proposed
        val draft = if (edited.productLink != previous.productLink || edited.category != previous.category) edited.copy(sizeRows = emptyList(), selectedSizeRowId = null) else edited
        if (draft != state.value.draft) pendingKey = null
        mutableState.value = state.value.copy(draft = draft, error = null)
    }
    fun setSizeRows(rows: List<ClosetSizeRow>) = editDraft { it.copy(sizeRows = rows, selectedSizeRowId = null) }
    fun selectSize(id: String) = editDraft { it.copy(selectedSizeRowId = id) }
    fun prefill() = runOperation { token, ticket ->
        val draft = state.value.draft
        val result = if (draft.isExample) {
            val example = com.inseong.coordit.data.fitlab.FitLabExample.product(draft.category)
            ClosetPrefill(example.productName, example.sizes.mapIndexed { index, row -> row.row(index) }, draft.category)
        } else repository.prefill(token, draft)
        if (current(ticket)) {
            pendingKey = null
            mutableState.value = state.value.copy(draft = state.value.draft.copy(name = result.name.orEmpty(), category = result.category ?: state.value.draft.category, sizeRows = result.rows, selectedSizeRowId = null))
        }
    }
    fun openItem(item: ClosetItem) {
        if (state.value.busy) return
        mutableState.value = state.value.copy(screen = ClosetScreen.Detail, detail = ClosetDetail(item), loading = true, error = null)
        runOperation { token, ticket ->
            val detail = repository.detail(token, item.id)
            if (current(ticket)) mutableState.value = state.value.copy(detail = detail)
        }
    }
    fun save() {
        if (state.value.busy) return
        val draft = state.value.draft
        val key = if (draft.isExample) "tutorial-example" else pendingKey ?: UUID.randomUUID().toString().also { pendingKey = it }
        try { draft.request(key) } catch (failure: IllegalArgumentException) { error(failure.message ?: "입력값을 확인해 주세요."); return }
        if (draft.isExample) {
            val item = ClosetItem("tutorial-clothing", draft.name, draft.category, draft.selectedSizeRow?.label)
            val row = draft.selectedSizeRow ?: ClosetSizeRow("example-size", "예시", draft.measurements())
            mutableState.value = state.value.copy(screen = ClosetScreen.Detail, detail = ClosetDetail(item, listOf(row)), error = null)
            return
        }
        mutableState.value = state.value.copy(screen = ClosetScreen.Saving)
        runOperation { token, ticket ->
            val detail = repository.create(token, draft, key)
            if (current(ticket) && registeringForFitLab) {
                val item = detail.item
                requireNotNull(homeRepository).registerReference(token, com.inseong.coordit.data.home.HomeGarment(item.id, item.name, item.category))
            }
            if (current(ticket)) {
                pendingKey = null
                mutableState.value = state.value.copy(screen = ClosetScreen.Detail, detail = detail, items = listOf(detail.item) + state.value.items.filter { it.id != detail.item.id })
                val full = repository.detail(token, detail.item.id)
                if (current(ticket)) mutableState.value = state.value.copy(detail = full)
            }
        }
    }
    fun rename(name: String) {
        val detail = state.value.detail ?: return
        runOperation { token, ticket ->
            val item = repository.rename(token, detail.item.id, name)
            if (current(ticket)) mutableState.value = state.value.copy(detail = detail.copy(item = item), items = state.value.items.map { if (it.id == item.id) item else it })
        }
    }
    fun delete() {
        val detail = state.value.detail ?: return
        runOperation { token, ticket ->
            repository.delete(token, detail.item.id)
            if (current(ticket)) mutableState.value = state.value.copy(screen = ClosetScreen.Overview, detail = null, items = state.value.items.filter { it.id != detail.item.id }, loading = true)
            refreshProfiles(token, ticket)
        }
    }
    fun back() {
        if (state.value.busy) return
        val next = when (state.value.screen) {
            ClosetScreen.Overview -> ClosetScreen.Overview
            ClosetScreen.Method, ClosetScreen.Detail -> ClosetScreen.Overview
            ClosetScreen.Saving -> screenFor(state.value.draft.method ?: ClosetMethod.Manual)
            else -> ClosetScreen.Method
        }
        mutableState.value = state.value.copy(screen = next, error = null)
    }
    private fun screenFor(method: ClosetMethod) = when (method) { ClosetMethod.Manual -> ClosetScreen.Manual; ClosetMethod.Link -> ClosetScreen.Link; ClosetMethod.Photo -> ClosetScreen.Photo }
}
