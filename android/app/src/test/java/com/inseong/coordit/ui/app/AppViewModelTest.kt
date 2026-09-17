package com.inseong.coordit.ui.app

import com.inseong.coordit.auth.GoogleCredential
import com.inseong.coordit.auth.WelcomeStore
import com.inseong.coordit.data.home.*
import com.inseong.coordit.data.local.SessionStore
import com.inseong.coordit.data.model.*
import com.inseong.coordit.data.remote.CoorditApi
import com.inseong.coordit.data.repository.SessionRepository
import com.inseong.coordit.ui.threadcharge.RewardedAdCallbacks
import com.inseong.coordit.ui.threadcharge.RewardedAdGateway
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.*
import okhttp3.ResponseBody.Companion.toResponseBody
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import retrofit2.HttpException
import retrofit2.Response
import java.io.IOException

@OptIn(ExperimentalCoroutinesApi::class)
class AppViewModelTest {
    private val dispatcher = StandardTestDispatcher()
    private val api = AccountApi()
    private val store = MemorySessionStore()
    private val welcome = MemoryWelcomeStore()
    private val homeApi = FakeHomeApi()
    private val session = SessionRepository(api, store)
    private fun model(rewardedAds: RewardedAdGateway = TestRewardedAdGateway()) = AppViewModel(session, welcome, HomeRepository(homeApi), rewardedAds)

    @Before fun setup() { Dispatchers.setMain(dispatcher) }
    @After fun teardown() { Dispatchers.resetMain() }

    @Test fun firstLaunchShowsWelcomeWithoutAccountRequests() = runTest {
        val model = model()
        assertEquals(AppStage.Restoring, model.state.value.stage)
        runCurrent()
        assertEquals(AppStage.Welcome, model.state.value.stage)
        assertEquals(0, api.statusCalls)
        assertNull(session.session.value)
    }

    @Test fun completedWelcomeSignedOutLaunchShowsAuthentication() = runTest {
        welcome.completed = true
        val model = model()
        runCurrent()
        assertEquals(AppStage.Authentication, model.state.value.stage)
        assertEquals(0, api.statusCalls)
    }

    @Test fun rejectedRestoreClearsCredentialsAndReturnsToAuthentication() = runTest {
        store.value = savedSession
        welcome.completed = true
        api.refreshResult = { throw http(401) }
        val model = model()
        runCurrent()
        assertEquals(AppStage.Authentication, model.state.value.stage)
        assertNull(store.value)
        assertNull(session.session.value)
        assertEquals(0, api.statusCalls)
    }

    @Test fun unavailableRestorePreservesCredentialsAndRetryReachesReturningWelcome() = runTest {
        store.value = savedSession
        api.refreshResult = { throw http(503) }
        val model = model()
        runCurrent()
        assertEquals(AppStage.AccountRecovery, model.state.value.stage)
        assertEquals(savedSession, store.value)
        assertNotNull(model.state.value.error)
        api.refreshResult = { savedSession }
        model.retryAccount()
        runCurrent()
        assertEquals(AppStage.ReturningWelcome, model.state.value.stage)
        assertEquals(savedSession, session.session.value)
        model.enterHome()
        assertEquals(AppStage.Home, model.state.value.stage)
    }

    @Test fun googleSessionLeavesAuthenticationWhileProfileIsPendingAndToleratesFailure() = runTest {
        val profile = CompletableDeferred<UserProfile>()
        api.profileResult = { profile.await() }
        val model = model()
        runCurrent()
        model.openAuthentication()
        model.googleCredential(requireNotNull(model.beginGoogle()), GoogleCredential("id-token", "nonce"))
        runCurrent()
        assertEquals(savedSession, store.value)
        assertEquals(savedSession, session.session.value)
        assertEquals(AppStage.LoadingAccount, model.state.value.stage)
        assertFalse(model.state.value.busy)
        profile.completeExceptionally(IOException("offline"))
        runCurrent()
        assertEquals(AppStage.Home, model.state.value.stage)
        assertNull(model.state.value.profile)
    }

    @Test fun statusFailureNeverBypassesOnboardingAndCanRetry() = runTest {
        store.value = savedSession
        api.statusResult = { throw http(503) }
        val model = model()
        runCurrent()
        assertEquals(AppStage.AccountRecovery, model.state.value.stage)
        assertEquals(0, api.profileCalls)
        assertEquals(0, homeApi.loadCalls)
        assertEquals(savedSession, store.value)
        api.statusResult = { OnboardingStatus(false) }
        model.retryAccount()
        runCurrent()
        assertEquals(AppStage.Onboarding, model.state.value.stage)
        assertFalse(welcome.completed)
        assertEquals(0, homeApi.loadCalls)
    }

    @Test fun incompleteAccountMustCompleteOnboardingBeforeHome() = runTest {
        store.value = savedSession
        api.statusResult = { OnboardingStatus(false) }
        val model = model()
        runCurrent()
        assertEquals(AppStage.Onboarding, model.state.value.stage)
        model.enterHome()
        assertEquals(AppStage.Onboarding, model.state.value.stage)
        api.completionResult = { throw http(422) }
        model.completeOnboarding(onboardingRequest)
        assertTrue(model.state.value.busy)
        runCurrent()
        assertEquals(AppStage.Onboarding, model.state.value.stage)
        assertNotNull(model.state.value.error)
        assertFalse(model.state.value.busy)
        assertFalse(welcome.completed)
        api.completionResult = { OnboardingCompletion(true, accountProfile, true) }
        model.completeOnboarding(onboardingRequest)
        runCurrent()
        assertEquals(AppStage.Home, model.state.value.stage)
        assertEquals(accountProfile, model.state.value.profile)
        assertTrue(welcome.completed)
        assertNull(model.state.value.error)
        assertEquals(1, homeApi.loadCalls)
        assertEquals(onboardingRequest, api.submitted)
    }

    @Test fun rewardedAdOnlyUpdatesBalanceAfterServerSettlement() = runTest {
        store.value = savedSession
        val rewardedAds = TestRewardedAdGateway()
        api.rewardBalance = 1
        val model = model(rewardedAds)
        runCurrent()
        model.openThreadCharge()
        runCurrent()
        assertEquals(ThreadChargeStatus.Ready, model.state.value.threadCharge.status)
        rewardedAds.reward()
        assertEquals(ThreadChargeStatus.AwaitingSettlement, model.state.value.threadCharge.status)
        advanceTimeBy(2_000)
        runCurrent()
        assertEquals(1, model.state.value.threadBalance)
        assertEquals(ThreadChargeStatus.Ready, model.state.value.threadCharge.status)
        assertEquals(2, api.rewardAttempts)
    }

    @Test fun incompleteSubmissionResponseDoesNotUnlockHome() = runTest {
        store.value = savedSession
        api.statusResult = { OnboardingStatus(false) }
        api.completionResult = { OnboardingCompletion(false, accountProfile, false) }
        val model = model()
        runCurrent()
        model.completeOnboarding(onboardingRequest)
        runCurrent()
        assertEquals(AppStage.Onboarding, model.state.value.stage)
        assertNotNull(model.state.value.error)
        assertFalse(welcome.completed)
        assertEquals(0, homeApi.loadCalls)
    }

    @Test fun logoutCancelsPendingAccountAndLateProfileCannotRepopulateState() = runTest {
        store.value = savedSession
        val profile = CompletableDeferred<UserProfile>()
        api.profileResult = { profile.await() }
        val model = model()
        runCurrent()
        model.logout()
        runCurrent()
        profile.complete(accountProfile)
        runCurrent()
        assertEquals(AppStage.Welcome, model.state.value.stage)
        assertNull(model.state.value.profile)
        assertNull(model.state.value.body)
        assertNull(store.value)
        assertNull(session.session.value)
        assertEquals(0, homeApi.loadCalls)
    }

    @Test fun logoutClearsVisibleAccountAndPendingHomeEvenWhenProviderCleanupFails() = runTest {
        store.value = savedSession
        val clothing = CompletableDeferred<List<HomeClothingResponse>>()
        homeApi.clothingResult = { clothing.await() }
        val model = model()
        runCurrent()
        assertEquals(accountProfile, model.state.value.profile)
        assertTrue(model.state.value.home.loading)
        model.logout { throw IOException("provider unavailable") }
        runCurrent()
        clothing.complete(listOf(HomeClothingResponse("private-item", "Private", "tshirt")))
        runCurrent()
        assertEquals(AppStage.Authentication, model.state.value.stage)
        assertNull(model.state.value.profile)
        assertNull(model.state.value.body)
        assertTrue(model.state.value.home.snapshot.items.isEmpty())
        assertFalse(model.state.value.home.loading)
        assertNull(store.value)
        assertNull(session.session.value)
    }

    @Test fun googleCancelAndFailureNeverCreateSession() = runTest {
        val model = model()
        runCurrent()
        model.openAuthentication()
        val canceled = requireNotNull(model.beginGoogle())
        model.googleCanceled(canceled)
        assertFalse(model.state.value.busy)
        assertNull(model.state.value.error)
        val failed = requireNotNull(model.beginGoogle())
        model.googleFailed(failed, IOException("provider failed"))
        assertFalse(model.state.value.busy)
        assertNotNull(model.state.value.error)
        assertEquals(AppStage.Authentication, model.state.value.stage)
        assertEquals(0, api.googleCalls)
        assertNull(store.value)
        assertNull(session.session.value)
    }

    @Test fun canceledGoogleAttemptCannotAuthenticateFromLateCredential() = runTest {
        val model = model()
        runCurrent()
        model.openAuthentication()
        val attempt = requireNotNull(model.beginGoogle())
        model.googleCanceled(attempt)
        model.googleCredential(attempt, GoogleCredential("late-token", "nonce"))
        runCurrent()
        assertEquals(AppStage.Authentication, model.state.value.stage)
        assertEquals(0, api.googleCalls)
        assertNull(store.value)
    }

    @Test fun logoutInvalidatesPendingGoogleCallback() = runTest {
        val model = model()
        runCurrent()
        model.openAuthentication()
        val attempt = requireNotNull(model.beginGoogle())
        model.logout()
        runCurrent()
        model.googleCredential(attempt, GoogleCredential("late-token", "nonce"))
        runCurrent()
        assertEquals(AppStage.Welcome, model.state.value.stage)
        assertEquals(0, api.googleCalls)
        assertNull(store.value)
    }

    @Test fun failedGoogleAttemptCannotAuthenticateFromLateCredential() = runTest {
        val model = model()
        runCurrent()
        model.openAuthentication()
        val attempt = requireNotNull(model.beginGoogle())
        model.googleFailed(attempt, IOException("provider failed"))
        model.googleCredential(attempt, GoogleCredential("late-token", "nonce"))
        runCurrent()
        assertEquals(AppStage.Authentication, model.state.value.stage)
        assertEquals(0, api.googleCalls)
        assertNull(store.value)
    }

    @Test fun duplicateGoogleCredentialIsExchangedOnlyOnce() = runTest {
        val model = model()
        runCurrent()
        model.openAuthentication()
        val attempt = requireNotNull(model.beginGoogle())
        val credential = GoogleCredential("id-token", "nonce")
        model.googleCredential(attempt, credential)
        model.googleCredential(attempt, credential)
        runCurrent()
        assertEquals(1, api.googleCalls)
        assertEquals(AppStage.Home, model.state.value.stage)
    }

    @Test fun failedSessionPersistenceCannotDismissAuthentication() = runTest {
        store.writeFailure = IOException("disk unavailable")
        val model = model()
        runCurrent()
        model.openAuthentication()
        model.googleCredential(requireNotNull(model.beginGoogle()), GoogleCredential("id-token", "nonce"))
        runCurrent()
        assertEquals(AppStage.Authentication, model.state.value.stage)
        assertFalse(model.state.value.busy)
        assertNotNull(model.state.value.error)
        assertNull(session.session.value)
        assertNull(store.value)
        assertEquals(0, api.statusCalls)
    }

    companion object {
        private val savedSession = AuthSession("access", "refresh", AuthUser("user", "test@example.com"))
        private val accountProfile = UserProfile("user", "test@example.com", "코디")
        private val onboardingRequest = OnboardingRequest("코디", consents = mapOf("terms" to OnboardingRequest.Consent(true, "1.0")))
        private fun http(code: Int) = HttpException(Response.error<Unit>(code, "failure".toResponseBody()))
    }

    private class MemorySessionStore : SessionStore {
        var value: AuthSession? = null
        var writeFailure: IOException? = null
        override suspend fun read() = value
        override suspend fun write(session: AuthSession) { writeFailure?.let { throw it }; value = session }
        override suspend fun clear() { value = null }
    }
    private class MemoryWelcomeStore : WelcomeStore {
        var completed = false
        override fun hasCompleted() = completed
        override suspend fun markCompleted() { completed = true }
    }
    private class AccountApi : CoorditApi {
        var refreshResult: suspend () -> AuthSession = { savedSession }
        var statusResult: suspend () -> OnboardingStatus = { OnboardingStatus(true) }
        var profileResult: suspend () -> UserProfile = { accountProfile }
        var completionResult: suspend () -> OnboardingCompletion = { OnboardingCompletion(true, accountProfile, true) }
        var statusCalls = 0
        var profileCalls = 0
        var googleCalls = 0
        var submitted: OnboardingRequest? = null
        var rewardBalance = 0
        var rewardAttempts = 0
        override suspend fun refresh(request: RefreshAuthRequest) = refreshResult()
        override suspend fun loginGoogle(request: SocialAuthRequest): AuthSession { googleCalls++; return savedSession }
        override suspend fun loginApple(request: SocialAuthRequest): AuthSession = error("Unexpected Apple request")
        override suspend fun onboardingStatus(authorization: String): OnboardingStatus { statusCalls++; return statusResult() }
        override suspend fun me(authorization: String): UserProfile { profileCalls++; return profileResult() }
        override suspend fun updateMe(authorization: String, request: UpdateProfileRequest) = accountProfile.copy(displayName = request.displayName)
        override suspend fun deleteMe(authorization: String) = Unit
        override suspend fun completeOnboarding(authorization: String, request: OnboardingRequest): OnboardingCompletion {
            submitted = request
            return completionResult()
        }
        override suspend fun bodyMeasurements(authorization: String) = listOf(BodyMeasurement(id = "body", heightCm = 170.0))
        override suspend fun createBodyMeasurement(authorization: String, request: BodyMeasurementRequest) = BodyMeasurement("body-new", request.heightCm, request.weightKg)
        override suspend fun threadBalance(authorization: String) = ThreadBalanceResponse(rewardBalance)
        override suspend fun createThreadRewardAttempt(authorization: String): ThreadRewardAttempt {
            rewardAttempts++
            return ThreadRewardAttempt("attempt-$rewardAttempts", "2026-09-17T00:10:00Z", "pending")
        }
        override suspend fun health() = BackendHealth(true, "test")
    }
    private class TestRewardedAdGateway : RewardedAdGateway {
        private var callbacks: RewardedAdCallbacks? = null
        override val isAvailable = true
        override fun prepare(customData: String, callbacks: RewardedAdCallbacks) {
            this.callbacks = callbacks
            callbacks.onReady()
        }
        override fun show(activity: android.app.Activity) = Unit
        override fun clear() { callbacks = null }
        fun reward() { requireNotNull(callbacks).onRewarded() }
    }
    private class FakeHomeApi : HomeApi {
        var loadCalls = 0
        var clothingResult: suspend () -> List<HomeClothingResponse> = { emptyList() }
        override suspend fun clothing(authorization: String): List<HomeClothingResponse> { loadCalls++; return clothingResult() }
        override suspend fun references(authorization: String) = emptyList<HomeReferenceResponse>()
        override suspend fun select(authorization: String, request: HomeReferenceRequest): HomeReferenceResponse = error("Unexpected selection")
        override suspend fun deactivate(authorization: String, id: String): HomeReferenceResponse = error("Unexpected deactivation")
    }
}
