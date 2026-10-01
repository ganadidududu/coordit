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

class ClosetViewModel(private val repository: ClosetRepository, private val sessions: SessionRepository) : ViewModel() {
    private val mutableState = MutableStateFlow(ClosetState())
    val state = mutableState.asStateFlow()
    private var work: Job? = null
    private var generation = 0L
    private var pendingKey: String? = null
    private var owner = sessions.session.value?.user?.id
    init {
        viewModelScope.launch {
            sessions.session.map { it?.user?.id }.distinctUntilChanged().collect { id ->
                if (owner != id) {
                    generation++; work?.cancel(); owner = id; pendingKey = null
                    mutableState.value = ClosetState()
                }
            }
        }
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
        pendingKey = null
        mutableState.value = state.value.copy(screen = ClosetScreen.Method, draft = ClosetDraft(), error = null)
    }
    fun chooseMethod(method: ClosetMethod) {
        if (state.value.busy) return
        editDraft { if (it.method != method) it.copy(method = method, sizeRows = emptyList(), selectedSizeRowId = null) else it }
        mutableState.value = state.value.copy(screen = screenFor(method), error = null)
    }
    fun editDraft(edit: (ClosetDraft) -> ClosetDraft) {
        if (state.value.busy) return
        val previous = state.value.draft
        val edited = edit(previous)
        val draft = if (edited.productLink != previous.productLink || edited.category != previous.category) edited.copy(sizeRows = emptyList(), selectedSizeRowId = null) else edited
        if (draft != state.value.draft) pendingKey = null
        mutableState.value = state.value.copy(draft = draft, error = null)
    }
    fun setSizeRows(rows: List<ClosetSizeRow>) = editDraft { it.copy(sizeRows = rows, selectedSizeRowId = null) }
    fun selectSize(id: String) = editDraft { it.copy(selectedSizeRowId = id) }
    fun prefill() = runOperation { token, ticket ->
        val result = repository.prefill(token, state.value.draft)
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
        val key = pendingKey ?: UUID.randomUUID().toString().also { pendingKey = it }
        try { draft.request(key) } catch (failure: IllegalArgumentException) { error(failure.message ?: "입력값을 확인해 주세요."); return }
        mutableState.value = state.value.copy(screen = ClosetScreen.Saving)
        runOperation { token, ticket ->
            val detail = repository.create(token, draft, key)
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
