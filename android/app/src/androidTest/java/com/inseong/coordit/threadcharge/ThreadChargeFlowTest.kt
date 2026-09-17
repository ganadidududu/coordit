package com.inseong.coordit.threadcharge

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import com.inseong.coordit.data.model.BodyMeasurement
import com.inseong.coordit.data.model.UserProfile
import com.inseong.coordit.preview.AccountPreviewActivity
import com.inseong.coordit.ui.app.ThreadChargeState
import com.inseong.coordit.ui.app.ThreadChargeStatus
import com.inseong.coordit.ui.mypage.MyPageScreen
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

class ThreadChargeFlowTest {
    @get:Rule val compose = createAndroidComposeRule<AccountPreviewActivity>()

    @Test fun chargeScreenRendersLoadingReadySettlementAndFailureStates() {
        var charge by mutableStateOf(ThreadChargeState(ThreadChargeStatus.LoadingAd, "광고를 준비하고 있어요."))
        var retryCount = 0
        compose.setContent {
            MyPageScreen(
                profile = UserProfile("user", "coordit@example.com", "코디터"),
                body = BodyMeasurement("body", 165.5, 54.2), threadBalance = 7, threadCharge = charge,
                busy = false, error = null, message = null, onBack = {}, onHome = {}, onCloset = {}, onFitLab = {}, onRefresh = {},
                onOpenThreadCharge = {}, onShowRewardedAd = {}, onRetryRewardedAd = { retryCount++ },
                onSaveProfile = {}, onSaveBody = { _, _ -> }, onLogout = {}, onDeleteAccount = {}, onClearMessage = {},
            )
        }

        click("thread-charge")
        capture("01-loading")
        compose.runOnUiThread { charge = ThreadChargeState(ThreadChargeStatus.Ready) }
        compose.waitForIdle()
        reopenCharge()
        capture("02-ready")
        compose.runOnUiThread { charge = ThreadChargeState(ThreadChargeStatus.AwaitingSettlement, "실타래 지급을 확인하고 있어요.") }
        compose.waitForIdle()
        reopenCharge()
        capture("03-settlement")
        compose.runOnUiThread { charge = ThreadChargeState(ThreadChargeStatus.Failed, "실타래 지급 확인이 지연되고 있어요. 잠시 뒤 다시 시도해 주세요.") }
        compose.waitForIdle()
        reopenCharge()
        compose.onNodeWithTag("thread-charge-retry").assertExists()
        capture("04-failure")
        compose.onNodeWithTag("thread-charge-retry").performClick()
        assertEquals(1, retryCount)
    }

    private fun click(tag: String) {
        compose.onNodeWithTag(tag).performClick()
        compose.waitForIdle()
    }

    private fun reopenCharge() {
        click("mypage-back")
        click("thread-charge")
    }

    private fun capture(name: String) {
        compose.runOnUiThread {
            androidx.core.view.WindowInsetsControllerCompat(compose.activity.window, compose.activity.window.decorView)
                .hide(androidx.core.view.WindowInsetsCompat.Type.ime())
        }
        compose.waitForIdle()
        android.os.SystemClock.sleep(500)
        val bitmap = androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot()
        val directory = java.io.File(compose.activity.getExternalFilesDir(null), "thread-charge-qa").apply { mkdirs() }
        java.io.File(directory, "$name.png").outputStream().use { bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it) }
        bitmap.recycle()
    }
}
