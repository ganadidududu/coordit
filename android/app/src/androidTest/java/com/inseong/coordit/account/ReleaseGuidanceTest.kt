package com.inseong.coordit.account

import android.graphics.Bitmap
import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Density
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelStore
import androidx.test.platform.app.InstrumentationRegistry
import com.inseong.coordit.auth.WelcomeStore
import com.inseong.coordit.closet.*
import com.inseong.coordit.data.home.*
import com.inseong.coordit.data.fitlab.*
import com.inseong.coordit.data.closet.ClosetRepository
import com.inseong.coordit.data.repository.SessionRepository
import com.inseong.coordit.fitlab.*
import com.inseong.coordit.preview.AccountPreviewActivity
import com.inseong.coordit.ui.app.*
import com.inseong.coordit.ui.closet.ClosetViewModel
import com.inseong.coordit.ui.fitlab.FitLabViewModel
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import java.io.File

class ReleaseGuidanceTest {
    @get:Rule val compose = createAndroidComposeRule<AccountPreviewActivity>()
    private val models = ViewModelStore()
    private lateinit var app: AppViewModel
    private lateinit var closet: ClosetViewModel
    private lateinit var fit: FitLabViewModel
    private val closetApi = ClosetFixture().apply { failCreate = false; failPrefill = false }
    private val fitApi = FitLabFixture()
    private val homeApi = ReleaseHomeApi()
    private var sharedConsumed = 0

    private fun start(firstUse: Boolean, comparisonBalance: Int = 7, fontScale: Float = 1f, sharedUrl: String? = null) {
        val preferences = compose.activity.getSharedPreferences("coordit-first-use-guidance-v2", 0)
        preferences.edit().clear().apply()
        if (!firstUse) preferences.edit().putBoolean("closet-test-user.FitLab", true).putBoolean("closet-test-user.Closet", true).apply()
        val authentication = ClosetAuthApi()
        val sessions = SessionRepository(object : com.inseong.coordit.data.remote.CoorditApi by authentication {
            override suspend fun refresh(request: com.inseong.coordit.data.model.RefreshAuthRequest) =
                com.inseong.coordit.data.model.AuthSession("test-access", "test-refresh", com.inseong.coordit.data.model.AuthUser("closet-test-user", "closet@example.invalid"))
        }, ClosetMemoryStore())
        runBlocking { sessions.loginGoogle("fixture-token", "fixture-nonce") }
        val home = HomeRepository(homeApi)
        compose.runOnUiThread {
            app = make(AppViewModel::class.java) { AppViewModel(sessions, object : WelcomeStore {
                override fun hasCompleted() = true
                override suspend fun markCompleted() {}
            }, home) }
            closet = make(ClosetViewModel::class.java) { ClosetViewModel(ClosetRepository(closetApi), sessions, home) }
            fit = make(FitLabViewModel::class.java) { FitLabViewModel(FitLabRepository(object : FitLabApi by fitApi {
                override suspend fun balance(auth: String) = com.inseong.coordit.data.model.ThreadBalanceResponse(comparisonBalance)
                override suspend fun references(auth: String, category: String) = homeApi.saved.map { FitLabReference(it.id!!, it.clothingItemId!!, "등록한 내 옷", category, true) }
            }), sessions, FitLabMemoryHistory(), FitLabMemorySubmissions()) }
        }
        compose.setContent {
            var pendingSharedUrl by remember { mutableStateOf(sharedUrl) }
            val density = LocalDensity.current
            CompositionLocalProvider(LocalDensity provides Density(density.density, fontScale)) {
                CoorditApp(app, true, {}, {}, closetModel = closet, fitLabModel = fit,
                    sharedProductUrl = pendingSharedUrl, onSharedProductConsumed = { pendingSharedUrl = null; sharedConsumed++ })
            }
        }
        compose.waitUntil(10_000) { app.state.value.stage == AppStage.ReturningWelcome }
        compose.runOnUiThread { app.enterHome() }
        compose.waitUntil(10_000) { app.state.value.stage == AppStage.Home }
        compose.waitForIdle()
    }

    @Test fun firstVisitsStartIndependentPracticeAndHelpStaysOnDemand() {
        try {
            start(true)
            compose.onNodeWithTag("coordit-screen-main04").assertIsDisplayed()
            compose.onNodeWithTag("usage-guide").assertDoesNotExist()
            compose.onNodeWithTag("practice-hint").assertDoesNotExist()
            capture("login-home-no-guide")
            tap("coordit-main04-new-fit-button")
            compose.waitUntil(10_000) { fit.state.value.draft.isExample }
            compose.onNodeWithTag("usage-guide").assertDoesNotExist()
            compose.onNodeWithTag("fitlab-product-url").assertTextContains(FitLabExample.link)
            capture("first-fitlab-entry")
            tap("practice-skip")
            compose.onNodeWithText("계속 따라하기").performClick()
            assertTrue(fit.state.value.draft.isExample)
            tap("practice-skip")
            capture("practice-skip-confirmation")
            compose.onNodeWithText("이번에는 건너뛰기").performClick()
            compose.onNodeWithTag("fitlab-source-url").assertExists()
            compose.onNodeWithContentDescription("HOME").performClick()
            compose.onNodeWithTag("coordit-screen-main04").assertIsDisplayed()
            compose.onNodeWithTag("usage-guide").assertDoesNotExist()
            tap("coordit-main04-closet-button")
            compose.waitUntil(10_000) { closet.state.value.draft.isExample }
            compose.onNodeWithTag("closet-url").assertTextContains(FitLabExample.link)
            capture("first-closet-entry")
            completeClosetExample()
            tap("closet-example-finish")
            compose.onNodeWithTag("closet-overview").assertExists()
            assertFalse(closet.state.value.draft.isExample)
            val preferences = compose.activity.getSharedPreferences("coordit-first-use-guidance-v2", 0)
            assertTrue(preferences.getBoolean("closet-test-user.FitLab", false))
            assertTrue(preferences.getBoolean("closet-test-user.Closet", false))
            compose.onNodeWithContentDescription("HOME").performClick()
            tap("coordit-main04-new-fit-button")
            compose.onNodeWithTag("fitlab-source-url").assertExists()
            assertFalse(fit.state.value.draft.isExample)
            compose.onNodeWithTag("fitlab-tutorial-restart").performClick()
            compose.onNodeWithTag("usage-guide").assertIsDisplayed()
            compose.onNodeWithTag("usage-topic-free").performScrollTo().performClick()
            capture("help-on-demand")
            compose.onNodeWithTag("usage-guide-close").performClick()
            compose.onNodeWithTag("fitlab-source-url").assertExists()
        } finally { compose.runOnUiThread { models.clear() } }
    }

    @Test fun firstFitLabPracticeRegistersMissingReferenceWithoutSavingOrCharging() {
        try {
            start(true, comparisonBalance = 0)
            tap("coordit-main04-new-fit-button")
            compose.waitUntil(10_000) { fit.state.value.draft.isExample }
            tap("fitlab-url-import")
            compose.waitUntil(10_000) { !fit.state.value.busy }
            capture("practice-free-summary")
            compose.onNodeWithTag("fitlab-free-summary").assertExists()
            tap("fitlab-review-continue")
            compose.waitUntil(10_000) { !fit.state.value.busy }
            assertTrue(fit.state.value.references.isEmpty())
            tap("fitlab-camera-comparison")
            capture("practice-camera-unavailable")
            compose.onNodeWithTag("camera-coming-soon-close").performClick()
            tap("fitlab-choose-closet")
            compose.onNodeWithTag("fitlab-reference-picker-empty").assertExists()
            capture("practice-empty-wardrobe")
            compose.onNodeWithTag("fitlab-reference-picker-close").performClick()
            tap("fitlab-manage-references")
            compose.waitUntil(10_000) { closet.state.value.draft.isExample }
            completeClosetExample()
            tap("closet-example-finish")
            compose.onNodeWithTag("fitlab-choose-closet").assertExists()
            assertTrue(fit.state.value.draft.isExample)
            assertEquals(1, fit.state.value.references.size)
            capture("practice-reference-return")
            tap("fitlab-choose-closet")
            compose.onNodeWithTag("fitlab-reference-tutorial-reference").performClick()
            capture("practice-reference-selection")
            compose.onNodeWithTag("fitlab-reference-picker-done").performClick()
            tap("fitlab-submit")
            compose.waitUntil(10_000) { fit.state.value.screen == com.inseong.coordit.data.fitlab.FitLabScreen.Result }
            capture("practice-result")
            compose.onNodeWithTag("fitlab-save-history").assertDoesNotExist()
            tap("fitlab-restart")
            assertFalse(fit.state.value.draft.isExample)
            assertTrue(fit.state.value.history.isEmpty())
            assertTrue(closetApi.requests.isEmpty())
            assertTrue(homeApi.saved.isEmpty())
            assertEquals(0, fitApi.productCalls)
            assertTrue(fitApi.recommendationKeys.isEmpty())
            assertEquals(0, fit.state.value.threadBalance)
            compose.onNodeWithTag("usage-guide").assertDoesNotExist()
        } finally { compose.runOnUiThread { models.clear() } }
    }

    @Test fun helpReplayRestoresReportAfterNestedReferencePractice() {
        try {
            start(true)
            tap("coordit-main04-new-fit-button")
            compose.waitUntil(10_000) { fit.state.value.draft.isExample }
            tap("practice-skip")
            compose.onNodeWithText("이번에는 건너뛰기").performClick()
            tap("fitlab-source-url")
            compose.onNodeWithTag("fitlab-product-url").performTextReplacement("https://shop.example/original")
            tap("fitlab-url-import")
            compose.waitUntil(10_000) { !fit.state.value.busy }
            val original = fit.state.value.draft
            compose.onNodeWithTag("fitlab-tutorial-restart").performClick()
            compose.onNodeWithTag("usage-guide-example").performClick()
            tap("fitlab-url-import")
            compose.waitUntil(10_000) { !fit.state.value.busy }
            tap("fitlab-review-continue")
            compose.waitUntil(10_000) { !fit.state.value.busy }
            assertTrue(fit.state.value.references.isEmpty())
            tap("fitlab-manage-references")
            completeClosetExample()
            tap("closet-example-finish")
            compose.onNodeWithTag("fitlab-choose-closet").assertExists()
            tap("practice-skip")
            compose.onNodeWithText("이번에는 건너뛰기").performClick()
            assertEquals(original, fit.state.value.draft)
            compose.onNodeWithTag("fitlab-free-summary").assertExists()
            assertFalse(closet.state.value.draft.isExample)
            assertTrue(closetApi.requests.isEmpty())
            assertEquals(0, fitApi.productCalls)
            capture("help-replay-restored-report")
        } finally { compose.runOnUiThread { models.clear() } }
    }

    @Test fun sharedLinkWaitsForFirstPracticeAndConsumesOnce() {
        try {
            val url = "https://shop.example/shared-product"
            start(true, sharedUrl = url)
            compose.waitUntil(10_000) { fit.state.value.draft.isExample }
            assertEquals(0, sharedConsumed)
            tap("practice-skip")
            compose.onNodeWithText("이번에는 건너뛰기").performClick()
            compose.waitUntil(10_000) { sharedConsumed == 1 }
            compose.onNodeWithTag("fitlab-product-url").assertTextContains(url)
            assertFalse(closet.state.value.draft.isExample)
            compose.onNodeWithTag("usage-guide").assertDoesNotExist()
            capture("shared-link-restored")
        } finally { compose.runOnUiThread { models.clear() } }
    }

    @Test fun freeReportCoachScrollsAwayAtLargeTextSize() {
        try {
            start(true, fontScale = 1.7f)
            tap("coordit-main04-new-fit-button")
            compose.waitUntil(10_000) { fit.state.value.draft.isExample }
            tap("fitlab-url-import")
            compose.waitUntil(10_000) { !fit.state.value.busy }
            compose.onNodeWithTag("fitlab-summary-highlight").assertDoesNotExist()
            capture("practice-free-summary-large-start")
            compose.onNodeWithTag("fitlab-review-continue").assertIsNotDisplayed()
            compose.onNodeWithTag("fitlab-scroll").performSemanticsAction(androidx.compose.ui.semantics.SemanticsActions.ScrollBy) { it(0f, 100_000f) }
            capture("practice-free-summary-large-scrolled")
            compose.onNodeWithTag("practice-hint").assertIsNotDisplayed()
            val editBounds = compose.onNodeWithTag("fitlab-edit-product").fetchSemanticsNode().boundsInRoot
            val compareBounds = compose.onNodeWithTag("fitlab-review-continue").fetchSemanticsNode().boundsInRoot
            assertTrue(editBounds.bottom <= compareBounds.top)
            compose.onNodeWithTag("fitlab-review-continue").assertIsDisplayed()
            capture("practice-free-summary-large-end")
            tap("fitlab-review-continue")
            compose.onNodeWithTag("fitlab-references").assertExists()
        } finally { compose.runOnUiThread { models.clear() } }
    }

    private fun completeClosetExample() {
        capture("closet-practice-link")
        tap("closet-submit")
        compose.waitUntil(10_000) { !closet.state.value.busy }
        tap("closet-size-example-M")
        capture("closet-practice-size")
        compose.onAllNodes(SemanticsMatcher.keyIsDefined(androidx.compose.ui.semantics.SemanticsActions.ScrollBy)).onFirst()
            .performSemanticsAction(androidx.compose.ui.semantics.SemanticsActions.ScrollBy) { it(0f, 100_000f) }
        capture("closet-practice-size-end")
        tap("closet-submit")
        compose.waitForIdle()
        capture("closet-practice-result")
        compose.onAllNodes(SemanticsMatcher.keyIsDefined(androidx.compose.ui.semantics.SemanticsActions.ScrollBy)).onFirst()
            .performSemanticsAction(androidx.compose.ui.semantics.SemanticsActions.ScrollBy) { it(0f, 100_000f) }
        capture("closet-practice-result-end")
        assertTrue(closetApi.requests.isEmpty())
    }

    @Test fun registeringReferenceReturnsToSameComparisonWithNewGarmentAvailable() {
        try {
            start(false)
            compose.onNodeWithTag("coordit-main04-new-fit-button").performClick()
            compose.waitUntil(10_000) { !fit.state.value.busy }
            tap("fitlab-source-url")
            compose.onNodeWithTag("fitlab-product-url").performTextReplacement("https://shop.example/product")
            InstrumentationRegistry.getInstrumentation().uiAutomation.executeShellCommand("input keyevent 111").close()
            tap("fitlab-url-import")
            compose.waitUntil(10_000) { fit.state.value.screen == com.inseong.coordit.data.fitlab.FitLabScreen.Review }
            tap("fitlab-review-continue")
            compose.waitUntil(10_000) { !fit.state.value.busy }
            tap("fitlab-manage-references")
            compose.onNodeWithTag("closet-url").performTextReplacement("https://shop.example/my-shirt")
            InstrumentationRegistry.getInstrumentation().uiAutomation.executeShellCommand("input keyevent 111").close()
            tap("closet-submit")
            compose.waitUntil(10_000) { !closet.state.value.busy }
            tap("closet-size-M")
            tap("closet-submit")
            compose.waitUntil(10_000) { !closet.state.value.busy }
            compose.onAllNodes(SemanticsMatcher.keyIsDefined(androidx.compose.ui.semantics.SemanticsActions.ScrollBy)).onFirst()
                .performSemanticsAction(androidx.compose.ui.semantics.SemanticsActions.ScrollBy) { it(0f, -100_000f) }
            capture("reference-registered")
            tap("closet-return-fitlab")
            compose.waitUntil(10_000) { !fit.state.value.busy }
            assertEquals("링크 티셔츠", fit.state.value.draft.productName)
            tap("fitlab-choose-closet")
            compose.onNodeWithTag("fitlab-reference-saved-ref").assertIsDisplayed()
            capture("registered-reference-picker")
            assertEquals(1, closetApi.requests.size)
            assertEquals(0, fitApi.productCalls)
        } finally { compose.runOnUiThread { models.clear() } }
    }

    @Test fun discardingPracticeDoesNotStartAnotherFeatureGuide() {
        try {
            start(true)
            tap("coordit-main04-new-fit-button")
            compose.waitUntil(10_000) { fit.state.value.draft.isExample }
            tap("fitlab-url-import")
            compose.waitUntil(10_000) { !fit.state.value.busy }
            tap("fitlab-review-continue")
            compose.waitUntil(10_000) { !fit.state.value.busy }
            tap("fitlab-discard-submission")
            compose.onNodeWithTag("fitlab-discard-confirm").performClick()
            compose.onNodeWithTag("usage-guide").assertDoesNotExist()
            assertFalse(closet.state.value.draft.isExample)
            assertFalse(fit.state.value.draft.isExample)
            assertTrue(fitApi.recommendationKeys.isEmpty())
            capture("example-discard-no-next-guide")
        } finally { compose.runOnUiThread { models.clear() } }
    }

    @Test fun insufficientThreadsOpensChargeAndBackPreservesComparison() {
        try {
            homeApi.saved += HomeReferenceResponse("saved-ref", "home-shirt", true)
            start(false, comparisonBalance = 0)
            compose.onNodeWithTag("coordit-main04-new-fit-button").performClick()
            compose.waitUntil(10_000) { !fit.state.value.busy }
            tap("fitlab-source-url")
            compose.onNodeWithTag("fitlab-product-url").performTextReplacement("https://shop.example/product")
            tap("fitlab-url-import")
            compose.waitUntil(10_000) { !fit.state.value.busy }
            tap("fitlab-review-continue")
            compose.waitUntil(10_000) { !fit.state.value.busy }
            tap("fitlab-choose-closet")
            compose.onNodeWithTag("fitlab-reference-saved-ref").performClick()
            compose.onNodeWithTag("fitlab-reference-picker-done").performClick()
            tap("fitlab-submit")
            compose.onNodeWithTag("fitlab-recharge-confirm").performClick()
            compose.onNodeWithTag("mypage-screen").assertIsDisplayed()
            compose.onNodeWithTag("mypage-back").assertTextContains("실타래 충전", substring = true)
            capture("charge-from-comparison")
            compose.waitUntil(10_000) { !app.state.value.busy }
            compose.onNodeWithTag("mypage-back").performClick()
            compose.onNodeWithTag("fitlab-choose-closet").assertExists()
            assertEquals("링크 티셔츠", fit.state.value.draft.productName)
            assertEquals(setOf("saved-ref"), fit.state.value.draft.selectedReferenceIds)
            assertEquals(0, fitApi.productCalls)
        } finally { compose.runOnUiThread { models.clear() } }
    }

    private fun <T : ViewModel> make(type: Class<T>, factory: () -> T): T = ViewModelProvider(models, object : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST") override fun <V : ViewModel> create(modelClass: Class<V>): V = factory() as V
    })[type]
    private fun tap(tag: String) {
        InstrumentationRegistry.getInstrumentation().uiAutomation.executeShellCommand("input keyevent 111").close()
        compose.waitForIdle()
        val node = compose.onNodeWithTag(tag).performScrollTo()
        val height = compose.onRoot().fetchSemanticsNode().boundsInRoot.height
        val excess = node.fetchSemanticsNode().boundsInRoot.bottom - height * .75f
        if (excess > 0f) {
            compose.onAllNodes(SemanticsMatcher.keyIsDefined(androidx.compose.ui.semantics.SemanticsActions.ScrollBy)).onFirst()
                .performSemanticsAction(androidx.compose.ui.semantics.SemanticsActions.ScrollBy) { it(0f, excess) }
            compose.waitForIdle()
        }
        node.assertIsDisplayed().performTouchInput { click(center) }
        compose.waitForIdle()
    }
    private fun capture(name: String) {
        compose.waitForIdle(); InstrumentationRegistry.getInstrumentation().waitForIdleSync()
        android.os.SystemClock.sleep(700)
        val bitmap = checkNotNull(InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot())
        val folder = File(compose.activity.getExternalFilesDir(null), "summary-inline").apply { mkdirs() }
        File(folder, "$name.png").outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
        bitmap.recycle()
    }
}

private class ReleaseHomeApi : HomeApi {
    val saved = mutableListOf<HomeReferenceResponse>()
    override suspend fun clothing(authorization: String) = listOf(HomeClothingResponse("home-shirt", "내 셔츠", "shirt"))
    override suspend fun references(authorization: String) = saved.toList()
    override suspend fun select(authorization: String, request: HomeReferenceRequest) = HomeReferenceResponse("saved-ref", request.clothingItemId, true).also { saved += it }
    override suspend fun deactivate(authorization: String, id: String) = saved.first { it.id == id }
}
