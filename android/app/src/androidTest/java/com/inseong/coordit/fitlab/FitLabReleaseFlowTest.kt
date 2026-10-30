package com.inseong.coordit.fitlab

import android.graphics.Bitmap
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelStore
import androidx.test.platform.app.InstrumentationRegistry
import com.inseong.coordit.closet.ClosetAuthApi
import com.inseong.coordit.closet.ClosetMemoryStore
import com.inseong.coordit.data.closet.ClosetPrefillRequest
import com.inseong.coordit.data.fitlab.*
import com.inseong.coordit.data.fitlab.FitLabScreen as Route
import com.inseong.coordit.data.model.ThreadBalanceResponse
import com.inseong.coordit.data.repository.SessionRepository
import com.inseong.coordit.preview.AccountPreviewActivity
import com.inseong.coordit.ui.fitlab.FitLabScreen
import com.inseong.coordit.ui.fitlab.FitLabViewModel
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import java.io.File

class FitLabReleaseFlowTest {
    @get:Rule val compose = createAndroidComposeRule<AccountPreviewActivity>()
    private val models = ViewModelStore()
    private lateinit var model: FitLabViewModel
    private var registered = 0
    private var recharged = 0

    private fun start(api: FitLabApi, loadBalance: Boolean = true) {
        val sessions = SessionRepository(ClosetAuthApi(), ClosetMemoryStore())
        runBlocking { sessions.loginGoogle("fixture-token", "fixture-nonce") }
        compose.runOnUiThread {
            model = ViewModelProvider(models, object : ViewModelProvider.Factory {
                @Suppress("UNCHECKED_CAST") override fun <T : ViewModel> create(modelClass: Class<T>): T =
                    FitLabViewModel(FitLabRepository(api), sessions, FitLabMemoryHistory(), FitLabMemorySubmissions()) as T
            })[FitLabViewModel::class.java]
        }
        compose.setContent { FitLabScreen(model, {}, {}, {}, onRegisterReference = { registered++ }, onRecharge = { recharged++ }) }
        if (loadBalance) compose.runOnUiThread { model.open() }
        ready()
    }

    @Test fun freeSummaryPickerCancellationCameraAndZeroBalancePopupsMatchRelease() {
        val fixture = FitLabFixture()
        start(object : FitLabApi by fixture { override suspend fun balance(auth: String) = ThreadBalanceResponse(0) })
        try {
            capture("sources")
            compose.onNodeWithTag("fitlab-source-manual").assertDoesNotExist()
            openLink()
            capture("url")
            tap("fitlab-url-import")
            ready()
            assertEquals(Route.Review, model.state.value.screen)
            compose.onNodeWithTag("fitlab-free-summary").assertExists()
            compose.onNodeWithTag("fitlab-submit").assertDoesNotExist()
            assertEquals(0, fixture.productCalls)
            assertTrue(fixture.recommendationKeys.isEmpty())
            assertEquals(0, model.state.value.threadBalance)
            compose.onNodeWithTag("fitlab-summary-highlight").assertDoesNotExist()
            capture("free-summary")
            compose.onNodeWithTag("fitlab-scroll").performSemanticsAction(SemanticsActions.ScrollBy) { it(0f, 100_000f) }
            val editBounds = compose.onNodeWithTag("fitlab-edit-product").fetchSemanticsNode().boundsInRoot
            val compareBounds = compose.onNodeWithTag("fitlab-review-continue").fetchSemanticsNode().boundsInRoot
            assertTrue(editBounds.bottom <= compareBounds.top)
            compose.onNodeWithTag("fitlab-review-continue").assertIsDisplayed()
            capture("free-summary-end", top = false)
            tap("fitlab-toggle-measurements")
            tap("fitlab-product-size-L")
            compose.onNodeWithTag("fitlab-product-size-L").assertIsSelected()
            compose.onNodeWithTag("fitlab-summary-size-difference").assertTextContains("L → M", substring = true)
            capture("measurements", top = false)
            compose.onNodeWithTag("fitlab-scroll").performSemanticsAction(SemanticsActions.ScrollBy) { it(0f, 100_000f) }
            capture("measurements-end", top = false)
            tap("fitlab-review-continue")
            ready()
            capture("comparison-empty-selection")
            tap("fitlab-camera-comparison")
            compose.onNodeWithText("카메라 측정 기능은 준비 중입니다!").assertIsDisplayed()
            capture("camera-notice", top = false)
            compose.onNodeWithTag("camera-coming-soon-close").performClick()
            tap("fitlab-choose-closet")
            capture("picker", top = false)
            compose.onNodeWithTag("fitlab-reference-ref-1").performClick()
            capture("picker-selected", top = false)
            compose.onNodeWithTag("fitlab-reference-picker-close").performClick()
            assertTrue(model.state.value.draft.selectedReferenceIds.isEmpty())
            compose.onNodeWithTag("fitlab-submit").assertIsNotEnabled()
            tap("fitlab-choose-closet")
            compose.onNodeWithTag("fitlab-reference-ref-1").assertIsNotSelected().performClick()
            InstrumentationRegistry.getInstrumentation().sendKeyDownUpSync(android.view.KeyEvent.KEYCODE_BACK)
            assertTrue(model.state.value.draft.selectedReferenceIds.isEmpty())
            tap("fitlab-choose-closet")
            compose.onNodeWithTag("fitlab-reference-ref-1").assertIsNotSelected().performClick()
            compose.onNodeWithTag("fitlab-reference-picker-done").performClick()
            assertEquals(setOf("ref-1"), model.state.value.draft.selectedReferenceIds)
            tap("fitlab-tutorial-restart", false)
            compose.onNodeWithText("내 옷과 비교하는 방법").assertIsDisplayed()
            compose.onNodeWithTag("usage-guide-example").assertDoesNotExist()
            capture("comparison-usage-guide", top = false)
            compose.onNodeWithTag("usage-guide-return").performClick()
            assertEquals(setOf("ref-1"), model.state.value.draft.selectedReferenceIds)
            tap("fitlab-submit")
            compose.onNodeWithText("실타래가 부족해요").assertIsDisplayed()
            capture("insufficient-threads", top = false)
            compose.onNodeWithTag("fitlab-recharge-confirm-cancel").performClick()
            assertEquals(0, fixture.productCalls)
            assertEquals(0, recharged)
            tap("fitlab-submit")
            compose.onNodeWithTag("fitlab-recharge-confirm").performClick()
            assertEquals(1, recharged)
            tap("fitlab-discard-submission")
            capture("discard-confirmation", top = false)
            compose.onNodeWithTag("fitlab-discard-confirm-cancel").performClick()
            assertEquals(2, model.state.value.draft.sizes.size)
            tap("fitlab-back", false)
            assertEquals(Route.Review, model.state.value.screen)
            tap("fitlab-review-continue")
            ready()
            tap("fitlab-manage-references")
            assertEquals(1, registered)
            assertEquals(0, fixture.productCalls)
        } finally { compose.runOnUiThread { models.clear() } }
    }

    @Test fun failedImportOffersFallbackAndRetainsLink() {
        val fixture = FitLabFixture()
        start(object : FitLabApi by fixture { override suspend fun prefill(auth: String, request: ClosetPrefillRequest) = throw java.io.IOException("offline") })
        try {
            openLink()
            tap("fitlab-url-import"); ready()
            capture("url-error")
            tap("fitlab-source-manual")
            assertEquals(Route.Manual, model.state.value.screen)
            assertEquals("https://shop.example/product", model.state.value.draft.productUrl)
            capture("manual-fallback")
        } finally { compose.runOnUiThread { models.clear() } }
    }

    @Test fun emptyPickerCanRetryOrRegisterWithoutSpendingThreads() {
        val fixture = FitLabFixture()
        start(object : FitLabApi by fixture { override suspend fun references(auth: String, category: String) = emptyList<FitLabReference>() })
        try {
            openLink(); tap("fitlab-url-import"); ready()
            tap("fitlab-review-continue"); ready()
            assertTrue(model.state.value.references.isEmpty())
            compose.runOnUiThread { model.registerExampleReference() }
            tap("fitlab-choose-closet")
            compose.onNodeWithTag("fitlab-reference-picker-empty").assertIsDisplayed()
            capture("picker-empty", top = false)
            compose.onNodeWithTag("fitlab-reference-picker-done").assertIsNotEnabled()
            compose.onNodeWithTag("fitlab-reference-picker-register").performClick()
            assertEquals(1, registered)
            assertFalse(model.state.value.referencePickerVisible)
            assertEquals(0, fixture.productCalls)
        } finally { compose.runOnUiThread { models.clear() } }
    }

    @Test fun exampleNeverWritesOrChargesAndRestoresPreviousDraft() {
        val fixture = FitLabFixture()
        start(fixture)
        try {
            openLink()
            compose.runOnUiThread { model.beginExample() }
            tap("fitlab-url-import"); ready()
            assertEquals(Route.Review, model.state.value.screen)
            tap("fitlab-review-continue"); ready()
            assertTrue(model.state.value.references.isEmpty())
            compose.runOnUiThread { model.registerExampleReference() }
            tap("fitlab-choose-closet")
            compose.onNodeWithTag("fitlab-reference-tutorial-reference").performClick()
            compose.onNodeWithTag("fitlab-reference-picker-done").performClick()
            tap("fitlab-submit"); ready()
            assertEquals(Route.Result, model.state.value.screen)
            assertEquals(7, model.state.value.threadBalance)
            assertEquals(0, fixture.productCalls)
            assertTrue(fixture.recommendationKeys.isEmpty())
            compose.onNodeWithTag("fitlab-save-history").assertDoesNotExist()
            capture("example-result")
            tap("fitlab-restart")
            assertEquals(Route.Url, model.state.value.screen)
            assertEquals("https://shop.example/product", model.state.value.draft.productUrl)
            assertFalse(model.state.value.draft.isExample)
            compose.runOnUiThread { model.beginExample() }
            tap("fitlab-back", false)
            capture("example-skip", top = false)
            compose.onNodeWithTag("fitlab-example-skip-cancel").performClick()
            assertTrue(model.state.value.draft.isExample)
            tap("fitlab-back", false)
            compose.onNodeWithTag("fitlab-example-skip").performClick()
            assertFalse(model.state.value.draft.isExample)
        } finally { compose.runOnUiThread { models.clear() } }
    }

    @Test fun coldSharedProductLoadsBalanceBeforeComparison() {
        val fixture = FitLabFixture()
        start(fixture, loadBalance = false)
        try {
            assertFalse(model.state.value.threadBalanceKnown)
            compose.runOnUiThread { assertTrue(model.importSharedProduct("https://shop.example/shared")) }
            ready()
            assertTrue(model.state.value.threadBalanceKnown)
            assertEquals(7, model.state.value.threadBalance)
            assertEquals("https://shop.example/shared", model.state.value.draft.productUrl)
            tap("fitlab-url-import"); ready()
            tap("fitlab-review-continue"); ready()
            tap("fitlab-choose-closet")
            compose.onNodeWithTag("fitlab-reference-ref-1").performClick()
            compose.onNodeWithTag("fitlab-reference-picker-done").performClick()
            tap("fitlab-submit"); ready()
            assertEquals(1, fixture.productCalls)
            assertEquals(1, fixture.recommendationKeys.size)
            assertEquals(0, recharged)
        } finally { compose.runOnUiThread { models.clear() } }
    }

    @Test fun failedReferencePopupCanReloadWithoutLosingProduct() {
        val fixture = FitLabFixture()
        var attempts = 0
        start(object : FitLabApi by fixture {
            override suspend fun references(auth: String, category: String): List<FitLabReference> {
                attempts++
                if (attempts == 1) throw java.io.IOException("offline")
                return fixture.references(auth, category)
            }
        })
        try {
            openLink(); tap("fitlab-url-import"); ready()
            tap("fitlab-review-continue"); ready()
            assertTrue(model.state.value.references.isEmpty())
            compose.runOnUiThread { model.registerExampleReference() }
            tap("fitlab-choose-closet")
            compose.onNodeWithTag("fitlab-reference-picker-retry").assertIsDisplayed()
            capture("picker-error", top = false)
            compose.onNodeWithTag("fitlab-reference-picker-retry").performClick(); ready()
            compose.onNodeWithTag("fitlab-reference-ref-1").performClick()
            compose.onNodeWithTag("fitlab-reference-picker-done").performClick()
            assertEquals(setOf("ref-1"), model.state.value.draft.selectedReferenceIds)
            assertEquals("링크 티셔츠", model.state.value.draft.productName)
            assertEquals(0, fixture.productCalls)
        } finally { compose.runOnUiThread { models.clear() } }
    }

    @Test fun lowerLinkImportWithBothLengthAliasesRemainsEditableAndCanSummarize() {
        val fixture = FitLabFixture()
        start(object : FitLabApi by fixture {
            override suspend fun prefill(auth: String, request: ClosetPrefillRequest) = com.inseong.coordit.data.closet.ClosetPrefillResponse(
                "팬츠", listOf(com.inseong.coordit.data.closet.ClosetSizeResponse("m", "M", 101.0, null, null, null, 39.0, 51.0, 30.0, 101.0)), "pants")
        })
        try {
            openLink(); tap("fitlab-url-import"); ready()
            assertEquals(Route.Review, model.state.value.screen)
            assertEquals(com.inseong.coordit.data.home.HomeCategory.Pants, model.state.value.draft.category)
            assertFalse(model.state.value.draft.sizes.first().measurements.containsKey("total_length"))
            capture("lower-free-summary")
            tap("fitlab-edit-product")
            compose.onNodeWithTag("fitlab-size-0-outseam").assertExists()
            compose.onNodeWithTag("fitlab-size-0-total_length").assertDoesNotExist()
            tap("fitlab-confirm-draft")
            assertEquals(Route.Review, model.state.value.screen)
            assertEquals(0, fixture.productCalls)
        } finally { compose.runOnUiThread { models.clear() } }
    }

    private fun openLink() {
        tap("fitlab-source-url")
        compose.onNodeWithTag("fitlab-product-url").performScrollTo().performTextReplacement("https://shop.example/product")
        InstrumentationRegistry.getInstrumentation().uiAutomation.executeShellCommand("input keyevent 111").close()
        compose.waitForIdle()
    }
    private fun ready() { compose.waitUntil(10_000) { !model.state.value.busy }; compose.waitForIdle() }
    private fun tap(tag: String, scroll: Boolean = true) {
        val node = compose.onNodeWithTag(tag)
        if (scroll) node.performScrollTo()
        if (tag.startsWith("fitlab-product-size-")) {
            repeat(8) {
                if (runCatching { node.assertIsDisplayed() }.isFailure) {
                    compose.onNodeWithTag("fitlab-scroll").performSemanticsAction(SemanticsActions.ScrollBy) { it(0f, 250f) }
                    compose.waitForIdle()
                }
            }
        }
        node.assertIsDisplayed()
        node.performTouchInput { click(center) }
        compose.waitForIdle()
    }
    private fun capture(name: String, top: Boolean = true) {
        if (top) compose.onNodeWithTag("fitlab-scroll").performSemanticsAction(SemanticsActions.ScrollBy) { it(0f, -100_000f) }
        compose.waitForIdle()
        InstrumentationRegistry.getInstrumentation().waitForIdleSync()
        android.os.SystemClock.sleep(700)
        val bitmap = checkNotNull(InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot())
        val folder = File(compose.activity.getExternalFilesDir(null), "summary-inline").apply { mkdirs() }
        File(folder, "$name.png").outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
        bitmap.recycle()
    }
}
