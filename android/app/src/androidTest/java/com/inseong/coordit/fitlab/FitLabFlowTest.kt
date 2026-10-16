package com.inseong.coordit.fitlab

import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelStore
import com.inseong.coordit.closet.ClosetAuthApi
import com.inseong.coordit.closet.ClosetMemoryStore
import com.inseong.coordit.data.closet.ClosetPrefillRequest
import com.inseong.coordit.data.closet.ClosetPrefillResponse
import com.inseong.coordit.data.fitlab.*
import com.inseong.coordit.data.fitlab.FitLabScreen as FitLabRoute
import com.inseong.coordit.data.model.ThreadBalanceResponse
import com.inseong.coordit.data.repository.SessionRepository
import com.inseong.coordit.preview.AccountPreviewActivity
import com.inseong.coordit.ui.fitlab.FitLabScreen
import com.inseong.coordit.ui.fitlab.FitLabViewModel
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Rule
import org.junit.Test
import java.io.IOException

class FitLabFlowTest {
    @get:Rule val compose = createAndroidComposeRule<AccountPreviewActivity>()

    @Test fun fitLabFlowRetriesWithoutDuplicatingCompletedWrites() {
        val api = FitLabFixture()
        val history = FitLabMemoryHistory()
        val submissions = FitLabMemorySubmissions()
        val sessions = SessionRepository(ClosetAuthApi(), ClosetMemoryStore())
        runBlocking { sessions.loginGoogle("fixture-token", "fixture-nonce") }
        val models = ViewModelStore()
        lateinit var model: FitLabViewModel
        compose.runOnUiThread {
            model = ViewModelProvider(models, object : ViewModelProvider.Factory {
                @Suppress("UNCHECKED_CAST") override fun <T : ViewModel> create(modelClass: Class<T>): T = FitLabViewModel(FitLabRepository(api), sessions, history, submissions) as T
            })[FitLabViewModel::class.java]
        }
        try {
            compose.setContent { FitLabScreen(model, {}, {}, {}) }
            compose.runOnUiThread { model.open() }
            ready(model); capture("01-sources")

            click("fitlab-source-url"); capture("02-url")
            click("fitlab-back")
            click("fitlab-source-ocr"); capture("03-ocr")
            click("fitlab-back")
            click("fitlab-source-manual"); capture("04-manual")
            fill("fitlab-product-name", "QA 티셔츠")
            fill("fitlab-size-label-0", "M")
            fill("fitlab-size-0-shoulder_width", "45")
            click("fitlab-lower")
            compose.onNodeWithTag("fitlab-category-cancel").assertExists()
            compose.onNodeWithTag("fitlab-category-cancel").performTouchInput { click(center) }
            compose.waitUntil(5_000) { compose.onAllNodesWithTag("fitlab-category-cancel").fetchSemanticsNodes().isEmpty() }
            assertEquals("QA 티셔츠", model.state.value.draft.productName)
            assertEquals(true, model.state.value.draft.upper)
            click("fitlab-confirm-draft")
            compose.waitUntil(5_000) { model.state.value.screen == FitLabRoute.Review || model.state.value.error != null }
            assertEquals("error=${model.state.value.error}, draft=${model.state.value.draft}", FitLabRoute.Review, model.state.value.screen)
            capture("05-review")
            click("fitlab-review-continue")
            ready(model)
            assertEquals(FitLabRoute.References, model.state.value.screen)
            capture("06-references")

            click("fitlab-reference-ref-1")
            click("fitlab-submit")
            ready(model)
            assertEquals(FitLabRoute.Loading, model.state.value.screen)
            assertNotNull(model.state.value.error)
            capture("07-retry")
            click("fitlab-retry")
            ready(model)
            assertEquals(FitLabRoute.Result, model.state.value.screen)
            assertEquals(1, api.productCalls)
            assertEquals(1, api.sizeCalls)
            assertEquals(2, api.recommendationKeys.size)
            assertEquals(api.recommendationKeys.first(), api.recommendationKeys.last())
            compose.onNodeWithTag("fitlab-result").assertExists()
            assertNotNull(model.state.value.reportError)
            tap("fitlab-retry-report")
            compose.waitUntil(5_000) { model.state.value.report != null || api.reportKeys.size >= 2 }
            ready(model)
            assertNotNull(model.state.value.report)
            compose.onNodeWithTag("fitlab-report-context").assertExists()
            compose.onNodeWithTag("fitlab-fit-point-silhouette").assertExists()
            compose.onNodeWithTag("fitlab-measurement-score-shoulder_width").assertExists()
            compose.onNodeWithTag("fitlab-report-reason").assertExists()
            compose.onNodeWithTag("fitlab-report-tradeoff").assertExists()
            assertEquals(2, api.reportKeys.size)
            assertEquals(api.reportKeys.first(), api.reportKeys.last())
            capture("08-result")
            captureFitProfile("08a-fit-profile")
            captureAt("fitlab-measurement-scores", "08a-part-scores")
            captureAfterScroll("08a-difference")
            captureAt("fitlab-report-overall", "08b-report")
            captureAt("fitlab-report-context", "08b-context")
            captureAt("fitlab-report-tradeoff", "08b-tradeoff")
            captureAt("fitlab-report-measurement-어깨", "08b-measurement")
            captureBottom("08c-actions")
            tap("fitlab-save-history")
            compose.waitUntil(5_000) { model.state.value.history.size == 1 || model.state.value.error != null }
            ready(model)
            assertEquals(1, model.state.value.history.size)
            tap("fitlab-restart")
            compose.waitForIdle()
            click("fitlab-history-analysis-1")
            assertEquals(FitLabRoute.HistoryDetail, model.state.value.screen)
            capture("09-history-detail")
            captureFitProfile("09a-history-fit-profile")
            captureBottom("09b-history-actions")
            tap("fitlab-delete-history")
            compose.waitUntil(5_000) { model.state.value.screen == FitLabRoute.Sources || model.state.value.error != null }
            ready(model)
            assertEquals(emptyList<FitLabHistorySnapshot>(), model.state.value.history)
            assertEquals(FitLabRoute.Sources, model.state.value.screen)
        } finally {
            compose.runOnUiThread { models.clear() }
        }
    }

    @Test fun restoresCheckpointAndIdempotencyKeyAfterViewModelRecreation() {
        val api = FitLabFixture()
        val history = FitLabMemoryHistory()
        val submissions = FitLabMemorySubmissions()
        val sessions = SessionRepository(ClosetAuthApi(), ClosetMemoryStore())
        runBlocking {
            sessions.loginGoogle("fixture-token", "fixture-nonce")
            submissions.save(
                FitLabPendingSubmission(
                    userId = "closet-test-user",
                    draft = FitLabDraft(
                        productName = "복원 티셔츠",
                        sizes = listOf(FitLabSizeDraft("size-local", "M", mapOf("shoulder_width" to 45.0))),
                        selectedReferenceIds = setOf("ref-1"),
                    ),
                    checkpoint = FitLabCheckpoint(
                        productId = "product-restored",
                        sizeIds = mapOf("size-local" to "size-restored"),
                        recommendationKey = "recommendation-restored-key",
                    ),
                ),
            )
        }
        val models = ViewModelStore()
        lateinit var model: FitLabViewModel
        compose.runOnUiThread {
            model = ViewModelProvider(models, object : ViewModelProvider.Factory {
                @Suppress("UNCHECKED_CAST") override fun <T : ViewModel> create(modelClass: Class<T>): T =
                    FitLabViewModel(FitLabRepository(api), sessions, history, submissions) as T
            })[FitLabViewModel::class.java]
        }
        try {
            compose.waitUntil(5_000) { model.state.value.error != null }
            assertEquals(FitLabRoute.Loading, model.state.value.screen)
            compose.runOnUiThread { model.submit() }
            compose.waitUntil(5_000) { api.recommendationKeys.isNotEmpty() }
            ready(model)
            assertEquals(0, api.productCalls)
            assertEquals(0, api.sizeCalls)
            assertEquals("recommendation-restored-key", api.recommendationKeys.single())
        } finally {
            compose.runOnUiThread { models.clear() }
        }
    }

    @Test fun urlImportCategoryChangeCanBeCancelledWithoutLosingRows() {
        val api = FitLabFixture()
        val sessions = SessionRepository(ClosetAuthApi(), ClosetMemoryStore())
        runBlocking { sessions.loginGoogle("fixture-token", "fixture-nonce") }
        val models = ViewModelStore()
        lateinit var model: FitLabViewModel
        compose.runOnUiThread {
            model = ViewModelProvider(models, object : ViewModelProvider.Factory {
                @Suppress("UNCHECKED_CAST") override fun <T : ViewModel> create(modelClass: Class<T>): T =
                    FitLabViewModel(FitLabRepository(api), sessions, FitLabMemoryHistory(), FitLabMemorySubmissions()) as T
            })[FitLabViewModel::class.java]
        }
        try {
            compose.setContent { FitLabScreen(model, {}, {}, {}) }
            click("fitlab-source-url")
            fill("fitlab-product-url", "https://shop.example/product")
            click("fitlab-url-import")
            ready(model)
            assertEquals(2, model.state.value.draft.sizes.size)
            click("fitlab-lower")
            compose.onNodeWithTag("fitlab-category-cancel").performTouchInput { click(center) }
            compose.waitUntil(5_000) { compose.onAllNodesWithTag("fitlab-category-cancel").fetchSemanticsNodes().isEmpty() }
            assertEquals(true, model.state.value.draft.upper)
            assertEquals(2, model.state.value.draft.sizes.size)
            assertEquals(45.0, model.state.value.draft.sizes.first().measurements["shoulder_width"])
        } finally {
            compose.runOnUiThread { models.clear() }
        }
    }

    private fun ready(model: FitLabViewModel) {
        compose.waitUntil(5_000) { !model.state.value.busy }
        compose.waitForIdle()
    }

    private fun click(tag: String) {
        val node = compose.onNodeWithTag(tag)
        if (tag != "fitlab-back") node.performScrollTo()
        node.performClick()
        compose.waitForIdle()
    }

    private fun fill(tag: String, value: String) {
        compose.onNodeWithTag(tag).performScrollTo().performTextReplacement(value)
        compose.waitForIdle()
    }

    private fun tap(tag: String) {
        androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().uiAutomation
            .executeShellCommand("input keyevent 111").close()
        compose.waitForIdle()
        compose.onNodeWithTag(tag).performScrollTo()
        compose.onNodeWithTag(tag).assertIsDisplayed().performTouchInput { click(center) }
        compose.waitForIdle()
    }

    private fun capture(name: String) {
        compose.waitForIdle()
        androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().uiAutomation
            .executeShellCommand("input keyevent 111").close()
        repeat(8) {
            compose.onNodeWithTag("fitlab-scroll")
                .performSemanticsAction(SemanticsActions.ScrollBy) { scroll -> scroll(0f, -10_000f) }
        }
        compose.waitForIdle()
        val bitmap = androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot()
        val directory = java.io.File(compose.activity.getExternalFilesDir(null), "fitlab-qa").apply { mkdirs() }
        java.io.File(directory, "$name.png").outputStream().use { bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it) }
        bitmap.recycle()
    }

    private fun captureAt(tag: String, name: String) {
        compose.onNodeWithTag(tag).performScrollTo()
        compose.onNodeWithTag(tag).assertIsDisplayed()
        compose.waitForIdle()
        val bitmap = androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot()
        val directory = java.io.File(compose.activity.getExternalFilesDir(null), "fitlab-qa").apply { mkdirs() }
        java.io.File(directory, "$name.png").outputStream().use { bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it) }
        bitmap.recycle()
    }

    private fun captureFitProfile(name: String) {
        compose.onNodeWithTag("fitlab-fit-point-silhouette").performScrollTo()
        compose.onNodeWithTag("fitlab-scroll").performTouchInput {
            swipe(
                start = androidx.compose.ui.geometry.Offset(center.x, center.y + 150f),
                end = androidx.compose.ui.geometry.Offset(center.x, center.y - 150f),
                durationMillis = 500,
            )
        }
        compose.waitForIdle()
        val bitmap = androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot()
        val directory = java.io.File(compose.activity.getExternalFilesDir(null), "fitlab-qa").apply { mkdirs() }
        java.io.File(directory, "$name.png").outputStream().use { bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it) }
        bitmap.recycle()
    }

    private fun captureAfterScroll(name: String) {
        repeat(3) {
            compose.onNodeWithTag("fitlab-scroll").performTouchInput {
                swipe(
                    start = androidx.compose.ui.geometry.Offset(center.x, center.y + 125f),
                    end = androidx.compose.ui.geometry.Offset(center.x, center.y - 125f),
                    durationMillis = 700,
                )
            }
        }
        compose.waitForIdle()
        val bitmap = androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot()
        val directory = java.io.File(compose.activity.getExternalFilesDir(null), "fitlab-qa").apply { mkdirs() }
        java.io.File(directory, "$name.png").outputStream().use { bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it) }
        bitmap.recycle()
    }

    private fun captureBottom(name: String) {
        repeat(8) {
            compose.onNodeWithTag("fitlab-scroll")
                .performSemanticsAction(SemanticsActions.ScrollBy) { scroll -> scroll(0f, 10_000f) }
        }
        compose.waitForIdle()
        val bitmap = androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot()
        val directory = java.io.File(compose.activity.getExternalFilesDir(null), "fitlab-qa").apply { mkdirs() }
        java.io.File(directory, "$name.png").outputStream().use { bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it) }
        bitmap.recycle()
    }
}

private class FitLabMemoryHistory : FitLabHistoryStorage {
    private val values = mutableListOf<FitLabHistorySnapshot>()
    override suspend fun load(userId: String) = values.filter { it.userId == userId }
    override suspend fun save(snapshot: FitLabHistorySnapshot): List<FitLabHistorySnapshot> {
        values.removeAll { it.userId == snapshot.userId && it.analysisId == snapshot.analysisId }
        values.add(0, snapshot)
        return load(snapshot.userId)
    }
    override suspend fun delete(userId: String, analysisId: String): List<FitLabHistorySnapshot> {
        values.removeAll { it.userId == userId && it.analysisId == analysisId }
        return load(userId)
    }
}

private class FitLabMemorySubmissions : FitLabSubmissionStorage {
    private val values = mutableMapOf<String, FitLabPendingSubmission>()
    override suspend fun load(userId: String) = values[userId]
    override suspend fun save(value: FitLabPendingSubmission) { values[value.userId] = value }
    override suspend fun clear(userId: String) { values.remove(userId) }
}

private class FitLabFixture : FitLabApi {
    var productCalls = 0
    var sizeCalls = 0
    val recommendationKeys = mutableListOf<String>()
    val reportKeys = mutableListOf<String>()

    override suspend fun balance(auth: String) = ThreadBalanceResponse(7)
    override suspend fun references(auth: String, category: String) = listOf(
        FitLabReference("ref-1", "closet-1", "잘 맞는 반팔", category, true),
        FitLabReference("ref-hidden", "closet-2", "숨긴 옷", category, false),
    )
    override suspend fun prefill(auth: String, request: ClosetPrefillRequest): ClosetPrefillResponse = ClosetPrefillResponse(
        "링크 티셔츠",
        listOf(
            com.inseong.coordit.data.closet.ClosetSizeResponse("url-m", "M", 68.0, 45.0, 52.0, 21.0, null, null, null, null),
            com.inseong.coordit.data.closet.ClosetSizeResponse("url-l", "L", 70.0, 47.0, 54.0, 22.0, null, null, null, null),
        ),
        "tshirt",
    )
    override suspend fun product(auth: String, request: FitLabProductRequest): FitLabProductResponse {
        productCalls++
        return FitLabProductResponse("product-1", request.productName, request.category)
    }
    override suspend fun size(auth: String, id: String, request: FitLabSizeRequest): FitLabSizeResponse {
        sizeCalls++
        return FitLabSizeResponse("size-1", request.sizeLabel)
    }
    override suspend fun recommend(auth: String, request: FitLabRecommendRequest): FitLabRecommendation {
        recommendationKeys += request.idempotencyKey
        if (recommendationKeys.size == 1) throw IOException("ambiguous result")
        return FitLabRecommendation(
            "analysis-1", "M", 93.5, "잘 맞아요", "기준 옷과 가장 비슷한 핏이에요.", "high",
            mapOf("shoulder_width" to 0.5, "chest_width" to 1.0),
            listOf(FitLabSizeScore("S", 78.0), FitLabSizeScore("M", 93.5), FitLabSizeScore("L", 82.0)),
            availableThreads = 6,
        )
    }
    override suspend fun report(auth: String, id: String, request: FitLabReportRequest): FitLabReportResponse {
        reportKeys += request.idempotencyKey
        if (reportKeys.size == 1) throw IOException("ambiguous report result")
        return FitLabReportResponse(
            id, "fixture", FitLabReportBody("M 사이즈 핏 리포트", "기준 옷과 비슷한 여유가 예상돼요.", recommendationReason = "M은 어깨와 가슴의 균형이 가장 가까워요.", garmentFitContext = "티셔츠에서는 어깨와 가슴의 균형을 확인해요.", sizeTradeoff = "M은 어깨, L은 가슴 여유가 유리해요.", measurementAnalysis = listOf(FitLabMeasurementAnalysis("어깨", "0.5cm 여유"))),
            FitLabChartData(
                fitPointScores = listOf(
                    FitLabFitPointScore("silhouette", "실루엣", 96.5),
                    FitLabFitPointScore("mobility", "활동성", 97.0),
                ),
                measurementScores = listOf(
                    FitLabMeasurementScore("shoulder_width", "어깨", 98.0, 0.5, "similar"),
                    FitLabMeasurementScore("chest_width", "가슴", 94.9, 1.0, "loose"),
                ),
                idealVsProduct = listOf(
                    FitLabComparison("shoulder_width", "어깨", 44.5, 45.0, 0.5, "비슷"),
                    FitLabComparison("chest_width", "가슴", 51.0, 52.0, 1.0, "여유"),
                ),
                differenceBar = listOf(
                    FitLabDifference("shoulder_width", "어깨", 0.5, "loose", "비슷"),
                    FitLabDifference("chest_width", "가슴", 1.0, "loose", "여유"),
                ),
                sizeScoreRanking = listOf(FitLabSizeScore("M", 93.5)),
            ), 5,
        )
    }
}
