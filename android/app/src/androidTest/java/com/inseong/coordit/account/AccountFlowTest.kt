package com.inseong.coordit.account

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelStore
import com.inseong.coordit.auth.*
import com.inseong.coordit.data.home.*
import com.inseong.coordit.data.local.SessionStore
import com.inseong.coordit.data.model.*
import com.inseong.coordit.data.remote.CoorditApi
import com.inseong.coordit.data.repository.SessionRepository
import com.inseong.coordit.preview.AccountPreviewActivity
import com.inseong.coordit.ui.app.*
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test

/** Test-only services exercise the real root navigation, repository, and form submission. */
class AccountFlowTest {
    @get:Rule val compose = createAndroidComposeRule<AccountPreviewActivity>()
    @Test fun freshSignInOnboardingHomeAndLogout() {
        val api = TestApi()
        val store = MemoryStore()
        val welcome = MemoryWelcome()
        val viewModels = ViewModelStore()
        lateinit var model: AppViewModel
        compose.runOnUiThread {
            model = ViewModelProvider(viewModels, object : ViewModelProvider.Factory {
                @Suppress("UNCHECKED_CAST") override fun <T : ViewModel> create(modelClass: Class<T>): T =
                    AppViewModel(SessionRepository(api, store), welcome, HomeRepository(EmptyHome())) as T
            })[AppViewModel::class.java]
        }
        try {
            compose.setContent {
                CoorditApp(model, true, onGoogle = {
                    model.beginGoogle()?.let { model.googleCredential(it, GoogleCredential("test-id-token", "test-raw-nonce")) }
                }, onLogout = { model.logout() })
            }
            compose.waitUntil(5_000) { model.state.value.stage == AppStage.Welcome }
            compose.onNodeWithTag("splash-signup-entry").performClick()
            compose.onNodeWithTag("splash-auth-google").performClick()
            compose.waitUntil(5_000) { model.state.value.stage == AppStage.AccountRecovery }
            capture("account-recovery")
            compose.onNodeWithText("다시 시도").performClick()
            compose.waitUntil(5_000) { model.state.value.stage == AppStage.Onboarding }
            compose.onNodeWithTag("onboarding-display-name").performTextReplacement("테스트사용자")
            compose.onNodeWithTag("onboarding-next").performClick()
            compose.onNodeWithTag("onboarding-skip").performClick()
            compose.onNodeWithTag("onboarding-consent-terms").performClick()
            compose.onNodeWithTag("onboarding-consent-privacy").performClick()
            compose.onNodeWithTag("onboarding-save").performClick()
            compose.waitUntil(5_000) { model.state.value.stage == AppStage.Home }
            compose.onNodeWithTag("coordit-screen-main04").assertIsDisplayed()
            assertEquals("테스트사용자", api.submitted?.displayName)
            assertTrue(welcome.completed)
            assertNotNull(store.value)
            compose.onNodeWithContentDescription("My").performClick()
            capture("account-menu")
            compose.onNodeWithTag("mypage-account").performClick()
            compose.onNodeWithTag("open-logout").performClick()
            compose.onNodeWithTag("confirm-action").performClick()
            compose.waitUntil(5_000) { model.state.value.stage == AppStage.Authentication }
            compose.onNodeWithTag("splash-auth-google").assertIsDisplayed()
            assertNull(store.value)
            assertNull(model.state.value.profile)
            assertTrue(model.state.value.home.snapshot.items.isEmpty())
        } finally { compose.runOnUiThread { viewModels.clear() } }
    }

    private fun capture(name: String) {
        compose.waitForIdle()
        android.os.SystemClock.sleep(550)
        val bitmap = androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot()
        val directory = java.io.File(compose.activity.getExternalFilesDir(null), "account-qa").apply { mkdirs() }
        java.io.File(directory, "$name.png").outputStream().use { bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it) }
        bitmap.recycle()
    }

    private class MemoryStore : SessionStore {
        var value: AuthSession? = null
        override suspend fun read() = value
        override suspend fun write(session: AuthSession) { value = session }
        override suspend fun clear() { value = null }
    }
    private class MemoryWelcome : WelcomeStore {
        var completed = false
        override fun hasCompleted() = completed
        override suspend fun markCompleted() { completed = true }
    }
    private class TestApi : CoorditApi {
        var submitted: OnboardingRequest? = null
        var statusFailures = 1
        val profile = UserProfile("test-user", "test@example.invalid", "테스트사용자")
        override suspend fun health() = BackendHealth(true, "test")
        override suspend fun loginGoogle(request: SocialAuthRequest) = AuthSession("test-access", "test-refresh", AuthUser(profile.id, profile.email))
        override suspend fun loginApple(request: SocialAuthRequest): AuthSession = error("not used")
        override suspend fun refresh(request: RefreshAuthRequest): AuthSession = error("not used")
        override suspend fun me(authorization: String) = profile
        override suspend fun updateMe(authorization: String, request: UpdateProfileRequest) = profile.copy(displayName = request.displayName)
        override suspend fun deleteMe(authorization: String) = Unit
        override suspend fun onboardingStatus(authorization: String): OnboardingStatus {
            if (statusFailures-- > 0) throw java.io.IOException("test network failure")
            return OnboardingStatus(false)
        }
        override suspend fun completeOnboarding(authorization: String, request: OnboardingRequest): OnboardingCompletion {
            submitted = request
            return OnboardingCompletion(true, profile.copy(displayName = request.displayName), false)
        }
        override suspend fun bodyMeasurements(authorization: String) = emptyList<BodyMeasurement>()
        override suspend fun createBodyMeasurement(authorization: String, request: BodyMeasurementRequest) = BodyMeasurement("body", request.heightCm, request.weightKg)
        override suspend fun threadBalance(authorization: String) = ThreadBalanceResponse(0)
    }
    private class EmptyHome : HomeApi {
        override suspend fun clothing(authorization: String) = emptyList<HomeClothingResponse>()
        override suspend fun references(authorization: String) = emptyList<HomeReferenceResponse>()
        override suspend fun select(authorization: String, request: HomeReferenceRequest): HomeReferenceResponse = error("not used")
        override suspend fun deactivate(authorization: String, id: String): HomeReferenceResponse = error("not used")
    }
}
