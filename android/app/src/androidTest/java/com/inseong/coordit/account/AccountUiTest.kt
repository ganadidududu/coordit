package com.inseong.coordit.account

import android.graphics.Bitmap
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.test.platform.app.InstrumentationRegistry
import com.inseong.coordit.data.home.*
import com.inseong.coordit.data.model.OnboardingRequest
import com.inseong.coordit.preview.AccountPreviewActivity
import com.inseong.coordit.ui.auth.AuthenticationScreen
import com.inseong.coordit.ui.home.*
import com.inseong.coordit.ui.onboarding.OnboardingScreen
import java.io.File
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test

class AccountUiTest {
    @get:Rule val compose = createAndroidComposeRule<AccountPreviewActivity>()

    private fun capture(name: String) {
        compose.waitForIdle()
        android.os.SystemClock.sleep(550)
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val directory = File(compose.activity.getExternalFilesDir(null), "account-qa").apply { mkdirs() }
        val bitmap = instrumentation.uiAutomation.takeScreenshot()
        File(directory, "$name.png").outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
        bitmap.recycle()
    }

    @Test fun authenticationSheetSupportsProvidersGuestAndEmailLogin() {
        val busy = mutableStateOf(false)
        val error = mutableStateOf<String?>(null)
        var google = 0
        var apple = 0
        var guest = 0
        var submitted: Pair<String, String>? = null
        var dismissed = 0
        compose.setContent {
            AuthenticationScreen(
                busy = busy.value,
                error = error.value,
                onGoogle = { google++ },
                onApple = { apple++ },
                onGuest = { guest++ },
                onEmail = { email, password -> submitted = email to password },
                onDismiss = { dismissed++ },
            )
        }
        capture("auth-default")
        compose.onNodeWithTag("splash-auth-google").performClick()
        compose.onNodeWithTag("splash-auth-guest").performClick()
        assertEquals(1, google)
        assertEquals(1, guest)
        compose.onNodeWithTag("splash-auth-email").performClick()
        compose.onNodeWithTag("splash-auth-email-field").performTextInput("coordit@example.com")
        compose.onNodeWithTag("splash-auth-password-field").performTextInput("password")
        compose.onNodeWithTag("splash-auth-email-submit").performClick()
        assertEquals("coordit@example.com" to "password", submitted)
        capture("auth-email")
        compose.onNodeWithTag("splash-auth-email-back").performClick()
        compose.runOnIdle { busy.value = true }
        compose.onNodeWithTag("splash-auth-google").assertIsNotEnabled()
        compose.onNodeWithTag("splash-auth-apple").assertIsNotEnabled()
        capture("auth-busy")
        compose.runOnIdle { busy.value = false; error.value = "로그인하지 못했어요. 다시 시도해 주세요." }
        compose.onNodeWithTag("splash-auth-error").assertIsDisplayed()
        capture("auth-error")
        compose.onNodeWithTag("splash-auth-apple").performClick()
        assertEquals(1, apple)
        InstrumentationRegistry.getInstrumentation().sendKeyDownUpSync(android.view.KeyEvent.KEYCODE_BACK)
        assertEquals(1, dismissed)
    }

    @Test fun onboardingValidatesPreservesDraftAndRequiresConsents() {
        val busy = mutableStateOf(false)
        val error = mutableStateOf<String?>(null)
        var request: OnboardingRequest? = null
        var exits = 0
        compose.setContent { OnboardingScreen(null, null, busy.value, error.value, { request = it }, { exits++ }) }
        capture("onboarding-profile")
        compose.onNodeWithTag("onboarding-next").performClick()
        compose.onNodeWithText("옷장 기록에 표시할 이름을 입력해 주세요.").assertIsDisplayed()
        compose.onNodeWithTag("onboarding-display-name").performTextInput("테스트사용자")
        compose.onNodeWithTag("onboarding-gender-female").performScrollTo().performClick()
        compose.onNodeWithTag("onboarding-next").performClick()
        compose.onNodeWithTag("onboarding-measurement-height").assertIsDisplayed()
        capture("onboarding-measurements")
        compose.onNodeWithTag("onboarding-skip").performClick()
        compose.onNodeWithTag("onboarding-save").assertIsNotEnabled()
        capture("onboarding-consent")
        compose.onNodeWithTag("onboarding-legal-terms").performClick()
        compose.onNodeWithTag("onboarding-legal-sheet").assertIsDisplayed()
        capture("onboarding-terms")
        compose.onNodeWithTag("onboarding-legal-close").performClick()
        compose.onNodeWithTag("onboarding-legal-privacy").performClick()
        capture("onboarding-privacy")
        compose.onNodeWithTag("onboarding-legal-close").performClick()
        compose.onNodeWithTag("onboarding-consent-terms").performClick()
        compose.onNodeWithTag("onboarding-consent-privacy").performClick()
        compose.onNodeWithTag("onboarding-save").performClick()
        assertEquals("테스트사용자", request?.displayName)
        assertEquals("female", request?.gender)
        assertNull(request?.bodyMeasurements?.heightCm)
        assertEquals(true, request?.consents?.get("terms_of_service")?.accepted)
        assertEquals(false, request?.consents?.get("marketing")?.accepted)
        compose.runOnIdle { busy.value = true }
        compose.onNodeWithTag("onboarding-save").assertIsNotEnabled()
        capture("onboarding-saving")
        compose.runOnIdle { busy.value = false; error.value = "저장하지 못했어요. 다시 시도해 주세요." }
        capture("onboarding-save-error")
        compose.onNodeWithTag("onboarding-back").performClick()
        compose.onNodeWithTag("onboarding-back").performClick()
        compose.onNodeWithTag("onboarding-display-name").assertTextContains("테스트사용자")
        compose.runOnUiThread { compose.activity.onBackPressedDispatcher.onBackPressed() }
        assertEquals(1, exits)
    }

    @Test fun homeLoadsSelectionAndKeepsSheetOnSaveFailure() {
        val state = mutableStateOf(HomeUiState())
        var committed: Set<String>? = null
        compose.setContent { HomeScreen(state.value, {}, { committed = it }, {}, {}, {}) }
        capture("home-empty")
        compose.onNodeWithTag("home-reference-select").performScrollTo().performClick()
        capture("home-picker-empty")
        InstrumentationRegistry.getInstrumentation().sendKeyDownUpSync(android.view.KeyEvent.KEYCODE_BACK)
        compose.runOnIdle { state.value = HomeUiState(HomeSnapshot(listOf(HomeGarment("test-shirt", "기준 셔츠", HomeCategory.Shirt)))) }
        compose.onNodeWithTag("home-reference-select").performScrollTo().performClick()
        compose.onNodeWithTag("home-reference-item-test-shirt").performClick()
        capture("home-picker-selected")
        compose.onNodeWithTag("home-reference-done").performClick()
        assertEquals(setOf("test-shirt"), committed)
        compose.runOnIdle { state.value = state.value.copy(saving = true) }
        compose.onNodeWithTag("home-reference-done").assertIsNotEnabled()
        compose.runOnIdle { state.value = state.value.copy(saving = false, error = "기준 의류를 저장하지 못했어요.") }
        compose.onNodeWithTag("home-reference-sheet").assertIsDisplayed()
        capture("home-picker-error")
        compose.runOnIdle { state.value = state.value.copy(saving = true, error = null) }
        compose.runOnIdle { state.value = HomeUiState(state.value.snapshot.copy(selectedIds = setOf("test-shirt"))) }
        compose.onNodeWithTag("home-reference-sheet").assertDoesNotExist()
        capture("home-selected")
    }
}
