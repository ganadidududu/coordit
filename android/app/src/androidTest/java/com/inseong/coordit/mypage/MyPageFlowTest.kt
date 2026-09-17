package com.inseong.coordit.mypage

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import com.inseong.coordit.data.model.BodyMeasurement
import com.inseong.coordit.data.model.UserProfile
import com.inseong.coordit.preview.AccountPreviewActivity
import com.inseong.coordit.ui.app.ThreadChargeState
import com.inseong.coordit.ui.app.ThreadChargeStatus
import com.inseong.coordit.ui.mypage.MyPageScreen
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

class MyPageFlowTest {
    @get:Rule val compose = createAndroidComposeRule<AccountPreviewActivity>()

    @Test fun allMyPageDestinationsAndSaveActionsWork() {
        var savedName = ""
        var savedBody = 0.0 to 0.0
        var loggedOut = false
        var deleted = false
        compose.setContent {
            MyPageScreen(
                profile = UserProfile("user", "coordit@example.com", "코디터", "female", "1998-04-12"),
                body = BodyMeasurement("body", 165.5, 54.2), threadBalance = 7,
                threadCharge = ThreadChargeState(ThreadChargeStatus.Ready), busy = false,
                error = null, message = null, onBack = {}, onHome = {}, onCloset = {}, onFitLab = {}, onRefresh = {},
                onOpenThreadCharge = {}, onShowRewardedAd = {}, onRetryRewardedAd = {},
                onSaveProfile = { savedName = it }, onSaveBody = { h, w -> savedBody = h to w },
                onLogout = { loggedOut = true }, onDeleteAccount = { deleted = true }, onClearMessage = {},
            )
        }
        capture("01-root")
        click("thread-charge"); compose.onNodeWithTag("thread-charge-rewarded-ad").assertExists(); compose.onNodeWithTag("thread-charge-purchase-notice").assertExists(); capture("02-charge"); click("mypage-back")

        click("mypage-settings"); capture("13-settings"); click("mypage-back")

        click("mypage-account"); capture("03-account")
        click("open-profile"); compose.onNodeWithContentDescription("이름").performTextReplacement("새 이름"); click("profile-save"); assertEquals("새 이름", savedName); capture("04-profile")
        click("mypage-back"); click("open-logout"); click("confirm-action"); assertTrue(loggedOut); capture("05-logout")
        click("mypage-back"); click("open-delete"); click("delete-ack"); click("delete-account"); assertTrue(deleted); capture("06-delete")

        click("mypage-back"); click("mypage-back"); click("mypage-body"); capture("07-body")
        click("body-edit"); compose.onNodeWithContentDescription("키").performTextReplacement("172.4"); compose.onNodeWithContentDescription("몸무게").performTextReplacement("61.8"); click("body-save"); assertEquals(172.4 to 61.8, savedBody); capture("08-body-edit")

        click("mypage-back"); click("mypage-back"); click("mypage-notifications"); capture("09-notifications")
        click("mypage-back"); click("mypage-privacy"); capture("10-privacy"); click("open-policy"); capture("11-policy")
        click("mypage-back"); click("open-terms"); capture("12-terms")
        click("mypage-back"); click("mypage-back"); compose.onNodeWithTag("mypage-account").assertExists()
    }

    private fun click(tag: String) {
        val node = compose.onNodeWithTag(tag)
        node.performClick(); compose.waitForIdle()
    }

    private fun capture(name: String) {
        compose.runOnUiThread {
            compose.activity.currentFocus?.clearFocus()
            androidx.core.view.WindowInsetsControllerCompat(compose.activity.window, compose.activity.window.decorView)
                .hide(androidx.core.view.WindowInsetsCompat.Type.ime())
        }
        compose.waitForIdle(); android.os.SystemClock.sleep(800)
        androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot().recycle()
        android.os.SystemClock.sleep(300)
        val bitmap = androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot()
        val directory = java.io.File(compose.activity.getExternalFilesDir(null), "mypage-qa").apply { mkdirs() }
        java.io.File(directory, "$name.png").outputStream().use { bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it) }
        bitmap.recycle()
        android.os.SystemClock.sleep(500)
    }
}
