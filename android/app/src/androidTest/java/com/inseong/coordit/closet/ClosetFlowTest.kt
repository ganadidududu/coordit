package com.inseong.coordit.closet

import androidx.compose.ui.test.*
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelStore
import com.inseong.coordit.data.closet.ClosetRepository
import com.inseong.coordit.data.closet.ClosetScreen as Route
import com.inseong.coordit.data.repository.SessionRepository
import com.inseong.coordit.preview.AccountPreviewActivity
import com.inseong.coordit.ui.closet.*
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test

class ClosetFlowTest {
    @get:Rule val compose = createAndroidComposeRule<AccountPreviewActivity>()
    @Test fun realClosetFlowWithIsolatedServices() {
        val api = ClosetFixture()
        val sessions = SessionRepository(ClosetAuthApi(), ClosetMemoryStore())
        runBlocking { sessions.loginGoogle("fixture-token", "fixture-nonce") }
        val models = ViewModelStore()
        lateinit var model: ClosetViewModel
        compose.runOnUiThread {
            model = ViewModelProvider(models, object : ViewModelProvider.Factory {
                @Suppress("UNCHECKED_CAST") override fun <T : ViewModel> create(modelClass: Class<T>): T = ClosetViewModel(ClosetRepository(api), sessions) as T
            })[ClosetViewModel::class.java]
        }
        try {
            compose.setContent { ClosetScreen(model, ClosetPhotos(), {}, {}, {}) }
            compose.runOnUiThread { model.load() }
            ready(model); capture("01-empty")
            compose.runOnUiThread { api.seed(); model.load() }
            ready(model); capture("02-upper")
            click("closet-bottom"); capture("03-lower")
            click("closet-top")
            click("closet-item-upper"); ready(model); capture("03b-reference-detail")
            click("closet-back")
            click("closet-add"); capture("04-method")
            click("closet-method-manual"); capture("05-manual")
            compose.onNodeWithTag("closet-submit").assertIsNotEnabled()
            assertTrue(api.requests.isEmpty())
            fill("closet-name", "QA 수동 티셔츠")
            listOf("48", "54", "70", "23").forEachIndexed { i, v -> fill("closet-measurement-$i", v) }
            compose.onNodeWithTag("closet-measurement-3").performImeAction()
            capture("06-manual-filled")
            click("closet-submit")
            ready(model); compose.onNodeWithTag("closet-save-retry").assertExists(); capture("07-save-error")
            val gate = CompletableDeferred<Unit>()
            api.saveGate = gate
            click("closet-save-retry")
            compose.waitUntil(5000) { model.state.value.busy && api.requests.size == 2 }
            capture("08-saving")
            gate.complete(Unit)
            ready(model); assertEquals(Route.Detail, model.state.value.screen)
            assertEquals(api.requests[0].idempotencyKey, api.requests[1].idempotencyKey)
            capture("09-detail")
            compose.onNodeWithText("FIT SCORE").performScrollTo(); capture("10-detail-scroll")
            click("closet-rename"); capture("11-rename")
            fill("closet-rename-input", "QA 수정한 티셔츠")
            click("closet-rename-save"); ready(model)
            assertEquals("QA 수정한 티셔츠", model.state.value.detail?.item?.name)
            click("closet-delete"); capture("12-delete")
            click("closet-delete-cancel"); assertEquals(0, api.deletes)
            click("closet-delete"); click("closet-delete-confirm"); ready(model)
            assertEquals(1, api.deletes); assertEquals(Route.Overview, model.state.value.screen)
            click("closet-add"); click("closet-method-link"); capture("13-link")
            fill("closet-url", "https://example.invalid/shirt")
            compose.onNodeWithTag("closet-url").performImeAction()
            click("closet-submit"); ready(model)
            assertNotNull(model.state.value.error); capture("14-link-error")
            click("closet-submit"); ready(model)
            assertEquals(2, model.state.value.draft.sizeRows.size)
            compose.onNodeWithTag("closet-submit").assertIsNotEnabled()
            click("closet-size-L"); assertEquals("L", model.state.value.draft.selectedSizeRowId); capture("15-size-choice")
            click("closet-submit"); ready(model)
            assertEquals("Link save must reach Detail: ${model.state.value}", Route.Detail, model.state.value.screen)
            assertEquals(3, api.requests.size)
            assertEquals("L", model.state.value.detail?.item?.sizeLabel)
            assertEquals(50.0, api.requests.last().size.shoulderWidth!!, 0.0)
            click("closet-back"); click("closet-add"); click("closet-method-photo"); capture("16-photo")
            compose.onNodeWithTag("closet-switch-manual").performScrollTo(); capture("17-photo-scroll")
            click("closet-switch-manual")
            assertEquals(Route.Manual, model.state.value.screen)
        } finally { compose.runOnUiThread { models.clear() } }
    }
    private fun ready(model: ClosetViewModel) { compose.waitUntil(5000) { !model.state.value.busy && !model.state.value.loading }; compose.waitForIdle() }
    private fun click(tag: String) {
        val node = compose.onNodeWithTag(tag)
        if (tag !in setOf("closet-back", "closet-rename-save", "closet-delete-confirm", "closet-delete-cancel")) {
            node.performScrollTo()
            val rootHeight = compose.onRoot().fetchSemanticsNode().boundsInRoot.height
            val excess = node.fetchSemanticsNode().boundsInRoot.bottom - rootHeight * .75f
            if (excess > 0f) {
                compose.onAllNodes(SemanticsMatcher.keyIsDefined(SemanticsActions.ScrollBy)).onFirst()
                    .performSemanticsAction(SemanticsActions.ScrollBy) { it(0f, excess) }
                compose.waitForIdle()
            }
        }
        node.performClick()
    }
    private fun fill(tag: String, value: String) { val node = compose.onNodeWithTag(tag); if (tag != "closet-rename-input") node.performScrollTo(); node.performTextReplacement(value) }
    private fun capture(name: String) {
        compose.waitForIdle()
        if (name !in setOf("10-detail-scroll", "11-rename", "12-delete", "14-link-error", "15-size-choice", "17-photo-scroll")) {
            compose.onAllNodes(SemanticsMatcher.keyIsDefined(SemanticsActions.ScrollBy)).onFirst()
                .performSemanticsAction(SemanticsActions.ScrollBy) { it(0f, -100000f) }
            compose.waitForIdle()
        }
        android.os.SystemClock.sleep(550)
        val bitmap = androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot()
        val directory = java.io.File(compose.activity.getExternalFilesDir(null), "closet-qa").apply { mkdirs() }
        java.io.File(directory, "$name.png").outputStream().use { bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it) }
        bitmap.recycle()
    }
}
