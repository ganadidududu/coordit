package com.inseong.coordit.fitlab

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.lifecycle.viewModelScope
import com.inseong.coordit.auth.WelcomeStore
import com.inseong.coordit.closet.ClosetAuthApi
import com.inseong.coordit.closet.ClosetMemoryStore
import com.inseong.coordit.data.fitlab.*
import com.inseong.coordit.data.home.*
import com.inseong.coordit.data.repository.SessionRepository
import com.inseong.coordit.preview.AccountPreviewActivity
import com.inseong.coordit.ui.app.*
import com.inseong.coordit.ui.fitlab.FitLabViewModel
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.cancel
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test

class AppParityFlowTest {
    @get:Rule val compose = createAndroidComposeRule<AccountPreviewActivity>()

    @Test fun backgroundAnalysisCompletionAndHomeHistoryUseTheSameSnapshot() {
        compose.activity.getSharedPreferences("guided-tutorials", 0).edit().putBoolean("fitlab.seen", true).commit()
        val api = FitLabFixture().apply {
            failRecommendation = false; failReport = false
            recommendationGate = CompletableDeferred()
        }
        val sessions = SessionRepository(ClosetAuthApi(), ClosetMemoryStore())
        val home = object : HomeApi {
            override suspend fun clothing(authorization: String) = emptyList<HomeClothingResponse>()
            override suspend fun references(authorization: String) = emptyList<HomeReferenceResponse>()
            override suspend fun select(authorization: String, request: HomeReferenceRequest): HomeReferenceResponse = error("Unexpected write")
            override suspend fun deactivate(authorization: String, id: String): HomeReferenceResponse = error("Unexpected write")
        }
        val welcome = object : WelcomeStore {
            override fun hasCompleted() = true
            override suspend fun markCompleted() = Unit
        }
        val app = AppViewModel(sessions, welcome, HomeRepository(home))
        val fit = FitLabViewModel(FitLabRepository(api), sessions, FitLabMemoryHistory(), FitLabMemorySubmissions())
        try {
            compose.setContent { CoorditApp(app, true, {}, {}, fitLabModel = fit) }
            compose.waitUntil(5_000) { app.state.value.stage == AppStage.Authentication }
            compose.runOnUiThread { app.loginEmail("fixture@example.invalid", "fixture-password") }
            compose.waitUntil(5_000) { app.state.value.stage == AppStage.Home && fit.state.value.accountReady }
            compose.onNodeWithTag("coordit-main04-new-fit-button").performScrollTo().performClick()
            compose.waitUntil(5_000) { !fit.state.value.busy }
            compose.runOnUiThread {
                fit.chooseSource(FitLabSource.Manual)
                fit.edit { it.copy(productName = "QA 티셔츠", sizes = listOf(FitLabSizeDraft("qa-size", "M", mapOf("shoulder_width" to 45.0))), selectedReferenceIds = setOf("ref-1")) }
                fit.submit()
            }
            compose.waitUntil(5_000) { fit.state.value.busy && fit.state.value.step == FitLabStep.Recommendation }
            compose.onNodeWithContentDescription("HOME").performClick()
            compose.onNodeWithTag("coordit-screen-main04").assertExists()
            compose.onNodeWithTag("fit-analysis-notice-running").assertExists()
            capture("analysis-running-home")
            compose.onNodeWithTag("fit-analysis-notice-dismiss").performClick()
            assertNull(fit.state.value.notice)
            assertTrue(fit.state.value.busy)
            api.recommendationGate?.complete(Unit)
            compose.waitUntil(5_000) { fit.state.value.report != null }
            compose.onNodeWithTag("fit-analysis-notice-completed").assertExists()
            capture("analysis-completed-home")
            compose.onNodeWithText("핏 분석이 완료됐어요. 눌러서 리포트를 확인하세요.").performClick()
            compose.onNodeWithTag("fitlab-result").assertExists()
            compose.onNodeWithTag("fitlab-save-history").performScrollTo().performClick()
            compose.waitUntil(5_000) { fit.state.value.history.size == 1 && !fit.state.value.busy }
            assertEquals(com.inseong.coordit.data.fitlab.FitLabScreen.Sources, fit.state.value.screen)
            compose.onNodeWithContentDescription("HOME").performClick()
            compose.onNodeWithTag("home-history-analysis-1").performScrollTo().assertIsDisplayed()
            capture("home-saved-history")
            compose.onNodeWithTag("home-history-analysis-1").performClick()
            compose.onNodeWithTag("fitlab-historydetail").assertExists()
            assertEquals("analysis-1", fit.state.value.selectedHistory?.analysisId)
            assertEquals(1, api.recommendationKeys.size)
            assertEquals(1, api.reportKeys.size)
        } finally { app.viewModelScope.cancel(); fit.viewModelScope.cancel() }
    }

    private fun capture(name: String) {
        compose.waitForIdle()
        val directory = java.io.File(compose.activity.getExternalFilesDir(null), "parity-qa").apply { mkdirs() }
        val bitmap = androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot()
        java.io.File(directory, "$name.png").outputStream().use { bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it) }
        bitmap.recycle()
    }
}
