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

    init {
        viewModelScope.launch {
            sessions.session.collect { session ->
                val next = session?.user?.id
                if (next != userId) {
                    userId = next; generation++; work?.cancel(); mutableState.value = FitLabState()
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

    fun open() {
        if (mutableState.value.screen == FitLabScreen.Sources) loadBalance()
    }
    fun chooseSource(source: FitLabSource) {
        if (state.value.busy) return
        mutableState.value = state.value.copy(screen = when (source) { FitLabSource.Manual -> FitLabScreen.Manual; FitLabSource.Ocr -> FitLabScreen.Ocr; FitLabSource.Url -> FitLabScreen.Url }, draft = FitLabDraft(source = source), error = null)
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
    fun prefill() = runWork(FitLabStep.Product) { token, ticket ->
        val draft = state.value.draft
        val uri = URI(draft.productUrl.trim())
        require(uri.scheme?.lowercase() in setOf("http", "https") && !uri.host.isNullOrBlank()) { "HTTP 또는 HTTPS 상품 링크인지 확인해 주세요." }
        val response = repository.prefill(token, uri.toString(), draft.category.wireName)
        val rows = response.sizes.mapIndexed { index, row ->
            val m = mapOf("shoulder_width" to row.shoulderWidth, "chest_width" to row.chestWidth, "total_length" to row.totalLength, "sleeve_length" to row.sleeveLength, "waist_width" to row.waistWidth, "hip_width" to row.hipWidth, "rise" to row.rise, "outseam" to row.outseam).mapNotNull { (k,v) -> v?.takeIf { it.isFinite() && it > 0 }?.let { k to it } }.toMap()
            FitLabSizeDraft(row.id ?: "url-$index", row.sizeLabel.orEmpty(), m)
        }.filter { it.measurements.isNotEmpty() }
        require(rows.isNotEmpty()) { "사이즈표를 찾지 못했어요. 사진이나 직접 입력을 이용해 주세요." }
        if (current(ticket)) mutableState.value = state.value.copy(draft = draft.copy(productName = response.productName.orEmpty(), sizes = rows), busy = false, step = FitLabStep.Idle)
    }
    fun loadReferences() = runWork(FitLabStep.References) { token, ticket ->
        val refs = repository.references(token, state.value.draft.category.wireName)
        if (current(ticket)) mutableState.value = state.value.copy(screen = FitLabScreen.References, references = refs, busy = false, step = FitLabStep.Idle, error = if (refs.isEmpty()) "선택할 수 있는 기준 옷이 없어요." else null)
    }
    fun toggleReference(id: String) {
        if (state.value.busy || state.value.references.none { it.id == id }) return
        edit { draft -> draft.copy(selectedReferenceIds = if (id in draft.selectedReferenceIds) draft.selectedReferenceIds - id else draft.selectedReferenceIds + id) }
    }
    fun openHistory(snapshot: FitLabHistorySnapshot) {
        if (!state.value.busy && snapshot.userId == userId) mutableState.value = state.value.copy(screen = FitLabScreen.HistoryDetail, selectedHistory = snapshot, error = null)
    }
    fun saveHistory() {
        if (state.value.busy || state.value.historySaved) return
        val session = sessions.session.value ?: run { mutableState.value = state.value.copy(error = "로그인이 필요해요."); return }
        val recommendation = state.value.recommendation ?: return
        val report = state.value.report ?: return
        val draft = state.value.draft
        work = viewModelScope.launch {
            mutableState.value = state.value.copy(busy = true, error = null)
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
        work = viewModelScope.launch {
            mutableState.value = state.value.copy(busy = true, step = FitLabStep.Report, reportError = null, error = null)
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
                if (current(ticket)) mutableState.value = state.value.copy(busy = false, reportError = message(error), step = FitLabStep.Complete)
            }
        }
    }
    fun submit() {
        if (state.value.busy) return
        val draft = state.value.draft
        draft.validationError()?.let { mutableState.value = state.value.copy(error = it); return }
        if (draft.selectedReferenceIds.isEmpty()) { mutableState.value = state.value.copy(error = "현재 카테고리와 맞는 기준 옷을 하나 이상 선택해 주세요."); return }
        val session = sessions.session.value ?: run { mutableState.value = state.value.copy(error = "로그인이 필요해요."); return }
        val ticket = ++generation
        work = viewModelScope.launch {
            mutableState.value = state.value.copy(screen = FitLabScreen.Loading, busy = true, error = null, reportError = null)
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
                if (current(ticket)) mutableState.value = state.value.copy(screen = FitLabScreen.Loading, busy = false, error = message(error))
            }
        }
    }
    fun restart() {
        if (state.value.busy) return
        userId?.let { owner -> viewModelScope.launch { submissionStore.clear(owner) } }
        mutableState.value = FitLabState(threadBalance = state.value.threadBalance, history = state.value.history)
    }
    fun back(): Boolean {
        if (state.value.busy) return false
        mutableState.value = when (state.value.screen) {
            FitLabScreen.Sources -> return false
            FitLabScreen.Manual, FitLabScreen.Ocr, FitLabScreen.Url -> state.value.copy(screen = FitLabScreen.Sources, error = null)
            FitLabScreen.Review -> state.value.copy(screen = when (state.value.draft.source) { FitLabSource.Manual -> FitLabScreen.Manual; FitLabSource.Ocr -> FitLabScreen.Ocr; FitLabSource.Url -> FitLabScreen.Url }, error = null)
            FitLabScreen.References -> state.value.copy(screen = FitLabScreen.Review, error = null)
            FitLabScreen.Loading -> state.value.copy(screen = FitLabScreen.References, error = null)
            FitLabScreen.Result -> FitLabState(threadBalance = state.value.threadBalance, history = state.value.history)
            FitLabScreen.HistoryDetail -> state.value.copy(screen = FitLabScreen.Sources, selectedHistory = null, error = null)
        }
        return true
    }
    private fun loadBalance() = runWork(FitLabStep.Idle) { token, ticket ->
        val value = repository.balance(token)
        if (current(ticket)) mutableState.value = state.value.copy(threadBalance = value, busy = false)
    }
    private fun runWork(step: FitLabStep, block: suspend (String, Long) -> Unit) {
        if (state.value.busy) return
        val session = sessions.session.value ?: run { mutableState.value = state.value.copy(error = "로그인이 필요해요."); return }
        val ticket = ++generation
        work = viewModelScope.launch {
            mutableState.value = state.value.copy(busy = true, step = step, error = null)
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
