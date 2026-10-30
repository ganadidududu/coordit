package com.inseong.coordit.ui.fitlab

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.inseong.coordit.data.fitlab.*
import com.inseong.coordit.data.home.HomeCategory
import com.inseong.coordit.data.repository.SessionRepository
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import retrofit2.HttpException
import java.net.URI
import java.util.UUID

class FitLabViewModel(
    private val repository: FitLabRepository,
    private val sessions: SessionRepository,
    private val historyStore: FitLabHistoryStorage,
    private val submissionStore: FitLabSubmissionStorage,
) : ViewModel() {
    private val mutableState = MutableStateFlow(FitLabState())
    val state = mutableState.asStateFlow()
    private var work: Job? = null
    private var generation = 0L
    private var userId: String? = null
    private var beforeExample: FitLabState? = null

    init {
        viewModelScope.launch {
            sessions.session.collect { session ->
                val next = session?.user?.id
                if (next != userId) {
                    userId = next; generation++; work?.cancel(); beforeExample = null; mutableState.value = FitLabState()
                    if (next != null) {
                        val loaded = runCatching { historyStore.load(next) }.getOrDefault(emptyList())
                        val pending = runCatching { submissionStore.load(next) }.getOrNull()
                        if (userId == next) {
                            mutableState.value = if (pending == null) {
                                mutableState.value.copy(history = loaded)
                            } else {
                                mutableState.value.copy(
                                    screen = if (pending.recommendation == null) FitLabScreen.Loading else FitLabScreen.Result,
                                    draft = pending.draft,
                                    checkpoint = pending.checkpoint,
                                    recommendation = pending.recommendation,
                                    history = loaded,
                                    step = if (pending.recommendation == null) FitLabStep.Recommendation else FitLabStep.Complete,
                                    error = if (pending.recommendation == null) "중단된 분석을 완료된 단계부터 이어갈 수 있어요." else null,
                                    reportError = if (pending.recommendation != null) "중단된 상세 리포트를 이어서 만들 수 있어요." else null,
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    fun updateBalance(balance: Int) { mutableState.value = state.value.copy(threadBalance = balance, threadBalanceKnown = true) }
    fun importSharedProduct(url: String): Boolean {
        if (state.value.busy || state.value.draft.isExample) return false
        restart()
        mutableState.value = state.value.copy(screen = FitLabScreen.Url, draft = FitLabDraft(source = FitLabSource.Url, productUrl = url))
        loadBalance()
        return true
    }
    fun dismissThreadNotice() { mutableState.value = state.value.copy(requiresThreads = false) }
    fun open() {
        if (mutableState.value.screen == FitLabScreen.References) loadReferences()
        else if (mutableState.value.screen == FitLabScreen.Sources) loadBalance()
    }
    fun beginExample(): Boolean {
        if (state.value.busy) return false
        if (!state.value.draft.isExample) beforeExample = state.value
        mutableState.value = FitLabState(screen = FitLabScreen.Url, threadBalance = state.value.threadBalance, history = state.value.history,
            draft = FitLabDraft(source = FitLabSource.Url, productUrl = FitLabExample.link, isExample = true))
        return true
    }
    fun registerExampleReference() {
        if (!state.value.draft.isExample) return
        val reference = FitLabExample.references(state.value.draft.category).single()
        acceptRegisteredReference(reference)
    }
    fun finishExample() {
        if (!state.value.draft.isExample) return
        mutableState.value = beforeExample ?: FitLabState(threadBalance = state.value.threadBalance, history = state.value.history)
        beforeExample = null
    }
    fun chooseSource(source: FitLabSource) {
        if (state.value.busy) return
        val draft = if (state.value.screen == FitLabScreen.Sources) FitLabDraft(source = source)
            else state.value.draft.copy(source = source)
        mutableState.value = state.value.copy(screen = when (source) { FitLabSource.Manual -> FitLabScreen.Manual; FitLabSource.Ocr -> FitLabScreen.Ocr; FitLabSource.Url -> FitLabScreen.Url }, draft = draft, error = null)
    }
    fun edit(transform: (FitLabDraft) -> FitLabDraft) {
        if (!state.value.busy) mutableState.value = state.value.copy(draft = transform(state.value.draft), error = null, checkpoint = FitLabCheckpoint(), recommendation = null, report = null)
    }
    fun setCategory(category: HomeCategory) = edit { draft ->
        draft.copy(category = category, sizes = draft.sizes.map { it.copy(measurements = emptyMap()) }, selectedReferenceIds = emptySet())
    }
    fun setRows(rows: List<FitLabSizeDraft>) = edit { it.copy(sizes = rows) }
    fun confirmDraft() {
        val error = state.value.draft.validationError()
        if (error != null) { mutableState.value = state.value.copy(error = error); return }
        mutableState.value = state.value.copy(screen = FitLabScreen.Review, error = null)
    }
    fun continueToReferences() = loadReferences()
    fun editProduct() {
        if (!state.value.busy) mutableState.value = state.value.copy(screen = FitLabScreen.Manual, error = null)
    }
    fun prefill() = runWork(FitLabStep.Product) { token, ticket ->
        val draft = state.value.draft
        val uri = runCatching { URI(draft.productUrl.trim()) }.getOrNull()
        require(uri != null && uri.scheme?.lowercase() in setOf("http", "https") && !uri.host.isNullOrBlank()) { "HTTP 또는 HTTPS 상품 링크인지 확인해 주세요." }
        val response = if (draft.isExample) FitLabExample.product(draft.category)
            else repository.prefill(token, uri.toString(), if (draft.automaticCategory) null else draft.category.wireName)
        val rows = response.sizes.mapIndexed { index, row ->
            val m = mapOf("shoulder_width" to row.shoulderWidth, "chest_width" to row.chestWidth, "total_length" to row.totalLength, "sleeve_length" to row.sleeveLength, "waist_width" to row.waistWidth, "hip_width" to row.hipWidth, "rise" to row.rise, "outseam" to row.outseam).mapNotNull { (k,v) -> v?.takeIf { it.isFinite() && it > 0 }?.let { k to it } }.toMap()
            FitLabSizeDraft(row.id ?: "url-$index", row.sizeLabel.orEmpty(), m)
        }.filter { it.measurements.isNotEmpty() }
        require(rows.isNotEmpty()) { "사이즈표를 찾지 못했어요. 사진이나 직접 입력을 이용해 주세요." }
        val category = if (draft.automaticCategory) HomeCategory.entries.firstOrNull { it.wireName == response.category } ?: draft.category else draft.category
        val updated = draft.copy(productFacts = response.productFacts, productUrl = response.productUrl ?: draft.productUrl, productName = response.productName.orEmpty(), brand = response.brand.orEmpty(), mallName = response.mallName.orEmpty(), category = category, sizes = rows.map { it.copy(measurements = normalizedFitLabMeasurements(category, it.measurements)) }, selectedReferenceIds = emptySet())
        val complete = updated.validationError() == null && updated.sizes.all { row ->
            com.inseong.coordit.data.fitlab.camera.GarmentMeasurementPolicy.dimensions(category.wireName).all { key ->
                row.measurements[key]?.let { com.inseong.coordit.data.fitlab.camera.GarmentMeasurementPolicy.plausible(key, it) } == true
            }
        }
        if (current(ticket)) mutableState.value = state.value.copy(screen = if (complete) FitLabScreen.Review else FitLabScreen.Manual, draft = updated, busy = false, step = FitLabStep.Idle, error = if (complete) null else updated.validationError() ?: "누락되거나 잘못 읽힌 값만 수정해주세요.")
    }
    fun loadReferences() {
        if (state.value.busy) return
        mutableState.value = state.value.copy(screen = FitLabScreen.References, error = null)
        runWork(FitLabStep.References) { token, ticket ->
            val balance = if (state.value.draft.isExample) null else repository.balance(token)
            val refs = if (state.value.draft.isExample) state.value.references else repository.references(token, state.value.draft.category.wireName)
            if (current(ticket)) mutableState.value = state.value.copy(references = refs, draft = state.value.draft.copy(selectedReferenceIds = state.value.draft.selectedReferenceIds.intersect(refs.map { it.id }.toSet())), threadBalance = balance ?: state.value.threadBalance, threadBalanceKnown = balance != null || state.value.threadBalanceKnown, busy = false, step = FitLabStep.Idle)
        }
    }
    fun acceptRegisteredReference(reference: FitLabReference): Boolean {
        if (state.value.busy || !reference.isActive || !referenceIsCompatible(reference.category, state.value.draft.category)) return false
        edit { it.copy(selectedReferenceIds = it.selectedReferenceIds + reference.id) }
        mutableState.value = state.value.copy(screen = FitLabScreen.References,
            references = state.value.references.filterNot { it.id == reference.id } + reference,
            referencePickerVisible = false)
        return true
    }
    fun showReferencePicker() { mutableState.value = state.value.copy(referencePickerVisible = true) }
    fun dismissReferencePicker() { mutableState.value = state.value.copy(referencePickerVisible = false) }
    fun confirmReferences(ids: Set<String>) {
        if (state.value.busy) return
        val valid = ids.intersect(state.value.references.map { it.id }.toSet())
        if (valid.isEmpty()) return
        edit { it.copy(selectedReferenceIds = valid) }
        dismissReferencePicker()
    }
    fun toggleReference(id: String) {
        if (state.value.busy || state.value.references.none { it.id == id }) return
        edit { draft -> draft.copy(selectedReferenceIds = if (id in draft.selectedReferenceIds) draft.selectedReferenceIds - id else draft.selectedReferenceIds + id) }
    }
    fun openHistory(snapshot: FitLabHistorySnapshot) {
        if (!state.value.busy && snapshot.userId == userId) mutableState.value = state.value.copy(screen = FitLabScreen.HistoryDetail, selectedHistory = snapshot, historyReturnScreen = state.value.screen, error = null)
    }
    fun saveHistory() {
        if (state.value.busy || state.value.historySaved || state.value.draft.isExample) return
        val session = sessions.session.value ?: run { mutableState.value = state.value.copy(error = "로그인이 필요해요."); return }
        val recommendation = state.value.recommendation ?: return
        val report = state.value.report ?: return
        val draft = state.value.draft
        mutableState.value = state.value.copy(busy = true, error = null)
        work = viewModelScope.launch {
            try {
                val snapshot = FitLabHistorySnapshot(
                    analysisId = recommendation.fitAnalysisResultId,
                    userId = session.user.id,
                    savedAt = System.currentTimeMillis(),
                    productName = draft.productName,
                    category = draft.category.wireName,
                    upper = draft.upper,
                    source = draft.source,
                    referenceCount = draft.selectedReferenceIds.size,
                    recommendation = recommendation,
                    report = report,
                )
                val values = historyStore.save(snapshot)
                if (sessions.session.value?.user?.id == session.user.id) mutableState.value = state.value.copy(history = values, historySaved = true, busy = false)
            } catch (error: Exception) {
                if (error is CancellationException) throw error
                mutableState.value = state.value.copy(busy = false, error = "핏 분석 히스토리를 저장하지 못했어요.")
            }
        }
    }
    fun deleteHistory() {
        val selected = state.value.selectedHistory ?: return
        if (state.value.busy || selected.userId != userId) return
        work = viewModelScope.launch {
            mutableState.value = state.value.copy(busy = true, error = null)
            try {
                val values = historyStore.delete(selected.userId, selected.analysisId)
                if (userId == selected.userId) mutableState.value = state.value.copy(screen = FitLabScreen.Sources, history = values, selectedHistory = null, busy = false)
            } catch (error: Exception) {
                if (error is CancellationException) throw error
                mutableState.value = state.value.copy(busy = false, error = "저장된 분석을 삭제하지 못했어요.")
            }
        }
    }
    fun retryReport() {
        if (state.value.busy || state.value.report != null) return
        val result = state.value.recommendation ?: return
        val session = sessions.session.value ?: return
        val ticket = generation
        mutableState.value = state.value.copy(busy = true, step = FitLabStep.Report, reportError = null, error = null)
        work = viewModelScope.launch {
            try {
                var checkpoint = state.value.checkpoint
                val key = checkpoint.reportKey ?: UUID.randomUUID().toString().also { checkpoint = checkpoint.copy(reportKey = it) }
                if (current(ticket)) mutableState.value = state.value.copy(checkpoint = checkpoint)
                submissionStore.save(FitLabPendingSubmission(session.user.id, draft = state.value.draft, checkpoint = checkpoint, recommendation = result))
                val report = repository.report(session.accessToken, result, key)
                submissionStore.clear(session.user.id)
                if (current(ticket)) mutableState.value = state.value.copy(report = report, reportError = null, checkpoint = checkpoint, busy = false, step = FitLabStep.Complete, threadBalance = report.availableThreads ?: state.value.threadBalance)
            } catch (error: Exception) {
                if (error is CancellationException) throw error
                if (current(ticket)) mutableState.value = state.value.copy(busy = false, reportError = message(error), step = FitLabStep.Complete, requiresThreads = error is HttpException && error.code() == 402)
            }
        }
    }
    fun submit() {
        if (state.value.busy) return
        val draft = state.value.draft
        draft.validationError()?.let { mutableState.value = state.value.copy(error = it); return }
        if (draft.selectedReferenceIds.isEmpty()) { mutableState.value = state.value.copy(error = "현재 카테고리와 맞는 기준 옷을 하나 이상 선택해 주세요."); return }
        if (draft.isExample) {
            val recommendation = FitLabExample.recommendation(draft)
            mutableState.value = state.value.copy(screen = FitLabScreen.Result, recommendation = recommendation, report = FitLabExample.report(recommendation), error = null)
            return
        }
        val session = sessions.session.value ?: run { mutableState.value = state.value.copy(error = "로그인이 필요해요."); return }
        val ticket = ++generation
        mutableState.value = state.value.copy(screen = FitLabScreen.Loading, busy = true, error = null, reportError = null)
        work = viewModelScope.launch {
            try {
                var checkpoint = state.value.checkpoint
                submissionStore.save(FitLabPendingSubmission(userId = session.user.id, draft = draft, checkpoint = checkpoint, recommendation = state.value.recommendation))
                var productId = checkpoint.productId
                if (productId == null) {
                    mutableState.value = state.value.copy(step = FitLabStep.Product)
                    productId = repository.product(session.accessToken, draft).id
                    checkpoint = checkpoint.copy(productId = productId)
                    submissionStore.save(FitLabPendingSubmission(session.user.id, draft, checkpoint))
                    if (current(ticket)) mutableState.value = state.value.copy(checkpoint = checkpoint)
                }
                for (row in draft.sizes.filter { it.id !in checkpoint.sizeIds }) {
                    mutableState.value = state.value.copy(step = FitLabStep.Sizes)
                    val created = repository.size(session.accessToken, productId, row, draft.source)
                    checkpoint = checkpoint.copy(sizeIds = checkpoint.sizeIds + (row.id to created.id))
                    submissionStore.save(FitLabPendingSubmission(session.user.id, draft, checkpoint))
                    if (current(ticket)) mutableState.value = state.value.copy(checkpoint = checkpoint)
                }
                var recommendation = state.value.recommendation
                if (recommendation == null) {
                    mutableState.value = state.value.copy(step = FitLabStep.Recommendation)
                    val key = checkpoint.recommendationKey ?: UUID.randomUUID().toString().also { checkpoint = checkpoint.copy(recommendationKey = it) }
                    submissionStore.save(FitLabPendingSubmission(session.user.id, draft, checkpoint))
                    if (current(ticket)) mutableState.value = state.value.copy(checkpoint = checkpoint)
                    recommendation = repository.recommend(session.accessToken, draft.selectedReferenceIds, productId, key)
                    submissionStore.save(FitLabPendingSubmission(session.user.id, draft, checkpoint, recommendation))
                    if (current(ticket)) mutableState.value = state.value.copy(checkpoint = checkpoint, recommendation = recommendation, threadBalance = recommendation.availableThreads ?: state.value.threadBalance)
                }
                var report = state.value.report
                var reportError: String? = null
                if (report == null) {
                    mutableState.value = state.value.copy(step = FitLabStep.Report)
                    val key = checkpoint.reportKey ?: UUID.randomUUID().toString().also { checkpoint = checkpoint.copy(reportKey = it) }
                    submissionStore.save(FitLabPendingSubmission(session.user.id, draft, checkpoint, recommendation))
                    if (current(ticket)) mutableState.value = state.value.copy(checkpoint = checkpoint)
                    try { report = repository.report(session.accessToken, recommendation, key) }
                    catch (error: Exception) {
                        if (error is CancellationException) throw error
                        if (error is HttpException && error.code() == 402) throw error
                        reportError = message(error)
                    }
                }
                if (report != null) submissionStore.clear(session.user.id)
                if (current(ticket)) mutableState.value = state.value.copy(screen = FitLabScreen.Result, checkpoint = checkpoint, recommendation = recommendation, report = report, reportError = reportError, step = FitLabStep.Complete, busy = false, error = null, threadBalance = report?.availableThreads ?: state.value.threadBalance)
            } catch (error: Exception) {
                if (error is CancellationException) throw error
                if (current(ticket)) mutableState.value = state.value.copy(screen = FitLabScreen.Loading, busy = false, error = message(error), requiresThreads = error is HttpException && error.code() == 402)
            }
        }
    }
    fun restart() {
        if (state.value.busy) return
        if (state.value.draft.isExample) { finishExample(); return }
        userId?.let { owner -> viewModelScope.launch { submissionStore.clear(owner) } }
        mutableState.value = FitLabState(threadBalance = state.value.threadBalance, threadBalanceKnown = state.value.threadBalanceKnown, history = state.value.history)
    }
    fun back(): Boolean {
        if (state.value.busy) return false
        mutableState.value = when (state.value.screen) {
            FitLabScreen.Sources -> return false
            FitLabScreen.Manual, FitLabScreen.Ocr, FitLabScreen.Url -> state.value.copy(screen = FitLabScreen.Sources, error = null)
            FitLabScreen.Review -> state.value.copy(screen = FitLabScreen.Sources, error = null)
            FitLabScreen.References -> state.value.copy(screen = FitLabScreen.Review, error = null)
            FitLabScreen.Loading -> state.value.copy(screen = FitLabScreen.References, error = null)
            FitLabScreen.Result -> FitLabState(threadBalance = state.value.threadBalance, history = state.value.history)
            FitLabScreen.HistoryDetail -> state.value.copy(screen = state.value.historyReturnScreen, selectedHistory = null, error = null)
        }
        return true
    }
    private fun loadBalance() = runWork(FitLabStep.Idle) { token, ticket ->
        val value = repository.balance(token)
        if (current(ticket)) mutableState.value = state.value.copy(threadBalance = value, threadBalanceKnown = true, busy = false)
    }
    private fun runWork(step: FitLabStep, block: suspend (String, Long) -> Unit) {
        if (state.value.busy) return
        val session = sessions.session.value ?: run { mutableState.value = state.value.copy(error = "로그인이 필요해요."); return }
        val ticket = ++generation
        mutableState.value = state.value.copy(busy = true, step = step, error = null)
        work = viewModelScope.launch {
            try { block(session.accessToken, ticket) }
            catch (error: Exception) { if (error is CancellationException) throw error; if (current(ticket)) mutableState.value = state.value.copy(busy = false, error = message(error)) }
        }
    }
    private fun current(ticket: Long) = ticket == generation && sessions.session.value?.user?.id == userId
    private fun message(error: Exception): String = when (error) {
        is HttpException -> if (error.code() == 402) "실타래가 부족해요. 충전 후 다시 시도해 주세요." else "핏 분석 요청에 실패했어요. (${error.code()})"
        is IllegalArgumentException -> error.message ?: "입력값을 확인해 주세요."
        else -> "연결을 확인하고 다시 시도해 주세요."
    }
}
