package com.inseong.coordit.ui.app

import android.app.Activity
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.inseong.coordit.auth.GoogleCredential
import com.inseong.coordit.auth.SignInUnavailable
import com.inseong.coordit.auth.WelcomeStore
import com.inseong.coordit.data.model.*
import com.inseong.coordit.data.repository.SessionRepository
import com.inseong.coordit.data.home.HomeRepository
import com.inseong.coordit.ui.home.HomeUiState
import com.inseong.coordit.ui.threadcharge.AdPrivacyGateway
import com.inseong.coordit.ui.threadcharge.AdPrivacyState
import com.inseong.coordit.ui.threadcharge.DisabledAdPrivacyGateway
import com.inseong.coordit.ui.threadcharge.DisabledRewardedAdGateway
import com.inseong.coordit.ui.threadcharge.RewardedAdCallbacks
import com.inseong.coordit.ui.threadcharge.RewardedAdGateway
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import retrofit2.HttpException

enum class AppStage { Restoring, Welcome, Authentication, LoadingAccount, AccountRecovery, Onboarding, ReturningWelcome, Home }
enum class ThreadChargeStatus { Idle, CheckingReadiness, CheckingConsent, LoadingAd, Ready, Presenting, AwaitingSettlement, Failed, Disabled }
data class ThreadChargeState(
    val status: ThreadChargeStatus = ThreadChargeStatus.Idle,
    val message: String? = null,
    val rewardedAdsEnabled: Boolean = false,
    val privacyOptionsRequired: Boolean = false,
    val privacyStatusText: String = "광고 개인정보 설정을 확인하고 있어요.",
) {
    val canWatchAd: Boolean get() = rewardedAdsEnabled && status == ThreadChargeStatus.Ready
    val isRewardedAdVisible: Boolean get() = rewardedAdsEnabled && status in setOf(
        ThreadChargeStatus.LoadingAd,
        ThreadChargeStatus.Ready,
        ThreadChargeStatus.Presenting,
        ThreadChargeStatus.AwaitingSettlement,
        ThreadChargeStatus.Failed,
    )
    val canRetry: Boolean get() = status == ThreadChargeStatus.Failed || status == ThreadChargeStatus.Disabled
}

private fun ThreadChargeState.transition(
    status: ThreadChargeStatus,
    message: String? = null,
    rewardedAdsEnabled: Boolean = this.rewardedAdsEnabled,
) = copy(status = status, message = message, rewardedAdsEnabled = rewardedAdsEnabled)

private fun ThreadChargeState.withPrivacy(state: AdPrivacyState) = copy(
    privacyOptionsRequired = state.privacyOptionsRequired,
    privacyStatusText = state.statusText,
)
data class AppState(
    val stage: AppStage = AppStage.Restoring,
    val busy: Boolean = false,
    val error: String? = null,
    val profile: UserProfile? = null,
    val body: BodyMeasurement? = null,
    val threadBalance: Int = 0,
    val threadCharge: ThreadChargeState = ThreadChargeState(),
    val settingsMessage: String? = null,
    val home: HomeUiState = HomeUiState(),
)

class AppViewModel(
    private val session: SessionRepository,
    private val welcome: WelcomeStore,
    private val homeRepository: HomeRepository,
    private val rewardedAds: RewardedAdGateway = DisabledRewardedAdGateway,
    private val adPrivacy: AdPrivacyGateway = DisabledAdPrivacyGateway,
) : ViewModel() {
    private val mutableState = MutableStateFlow(AppState())
    val state = mutableState.asStateFlow()
    private var accountWork: Job? = null
    private var homeWork: Job? = null
    private var generation = 0L
    private var providerAttempt = 0L
    private var rewardWork: Job? = null
    private var rewardAccessWork: Job? = null
    private var rewardAttemptToken = 0L
    private var rewardBalanceBefore = 0
    private var rewardEarned = false

    init { restore() }

    fun restore() {
        accountWork?.cancel()
        mutableState.value = AppState()
        accountWork = viewModelScope.launch {
            try {
                val restored = session.restore()
                if (restored == null) signedOut() else loadAccount(returning = true)
            } catch (error: Exception) {
                if (error is CancellationException) throw error
                if (error is HttpException && error.code() in setOf(400, 401, 403)) signedOut()
                else mutableState.value = AppState(stage = AppStage.AccountRecovery, error = "로그인 상태를 복원하지 못했어요.\n연결을 확인하고 다시 시도해 주세요.")
            }
        }
    }
    private fun signedOut() {
        mutableState.value = AppState(stage = if (welcome.hasCompleted()) AppStage.Authentication else AppStage.Welcome)
    }
    fun openAuthentication() { mutableState.update { it.copy(stage = AppStage.Authentication, error = null) } }
    fun backToWelcome() {
        if (!state.value.busy) mutableState.update { it.copy(stage = AppStage.Welcome, error = null) }
    }
    fun beginGoogle(): Long? {
        if (state.value.busy || state.value.stage != AppStage.Authentication) return null
        mutableState.update { it.copy(busy = true, error = null) }
        return ++providerAttempt
    }
    fun googleCanceled(attempt: Long) {
        if (attempt == providerAttempt) { providerAttempt++; mutableState.update { it.copy(busy = false) } }
    }
    fun googleFailed(attempt: Long, error: Exception) {
        if (attempt == providerAttempt) { providerAttempt++; mutableState.update { it.copy(busy = false, error = userError(error)) } }
    }
    fun googleCredential(attempt: Long, credential: GoogleCredential) {
        if (attempt != providerAttempt || !state.value.busy || state.value.stage != AppStage.Authentication) return
        providerAttempt++
        accountWork = viewModelScope.launch {
            try {
                session.loginGoogle(credential.idToken, credential.rawNonce)
                // Dismiss authentication as soon as the session is safely persisted.
                mutableState.update { it.copy(stage = AppStage.LoadingAccount, busy = false, error = null) }
                loadAccount(returning = false)
            } catch (error: Exception) {
                if (error is CancellationException) throw error
                val stage = if (session.session.value == null) AppStage.Authentication else AppStage.AccountRecovery
                mutableState.update { it.copy(stage = stage, busy = false, error = userError(error)) }
            }
        }
    }
    fun appleUnavailable() {
        if (!state.value.busy) mutableState.update { it.copy(error = "Android에서는 Apple 로그인을 아직 사용할 수 없어요. Google 계정으로 계속해 주세요.") }
    }
    fun loginGuest() = authenticateWith { session.loginGuest() }
    fun loginEmail(email: String, password: String) {
        if (email.trim().isEmpty() || password.isEmpty()) {
            mutableState.update { it.copy(error = "이메일과 비밀번호를 입력해 주세요.") }
            return
        }
        authenticateWith { session.loginEmail(email, password) }
    }
    private fun authenticateWith(signIn: suspend () -> Unit) {
        if (state.value.busy || state.value.stage != AppStage.Authentication) return
        mutableState.update { it.copy(busy = true, error = null) }
        accountWork = viewModelScope.launch {
            try {
                signIn()
                mutableState.update { it.copy(stage = AppStage.LoadingAccount, busy = false, error = null) }
                loadAccount(returning = false)
            } catch (error: Exception) {
                if (error is CancellationException) throw error
                val stage = if (session.session.value == null) AppStage.Authentication else AppStage.AccountRecovery
                mutableState.update { it.copy(stage = stage, busy = false, error = userError(error)) }
            }
        }
    }
    fun retryAccount() {
        if (session.session.value == null) { restore(); return }
        mutableState.update { it.copy(stage = AppStage.LoadingAccount, error = null) }
        accountWork = viewModelScope.launch {
            try { loadAccount(returning = false) }
            catch (error: Exception) {
                if (error is CancellationException) throw error
                mutableState.update { it.copy(stage = AppStage.AccountRecovery, error = userError(error)) }
            }
        }
    }
    private suspend fun loadAccount(returning: Boolean) {
        val status = session.loadOnboardingStatus()
        val profile = optional { session.loadProfile() }
        val body = optional { session.loadBodyMeasurements().firstOrNull() }
        mutableState.update {
            it.copy(profile = profile, body = body, error = null, busy = false,
                stage = if (!status.onboardingComplete) AppStage.Onboarding else if (returning) AppStage.ReturningWelcome else AppStage.Home)
        }
        if (status.onboardingComplete) {
            welcome.markCompleted()
            refreshHome()
        }
    }
    fun completeOnboarding(request: OnboardingRequest) {
        if (state.value.busy || state.value.stage != AppStage.Onboarding) return
        mutableState.update { it.copy(busy = true, error = null) }
        accountWork = viewModelScope.launch {
            try {
                val result = session.completeOnboarding(request)
                check(result.onboardingComplete) { "Onboarding incomplete" }
                welcome.markCompleted()
                mutableState.update { it.copy(stage = AppStage.Home, busy = false, profile = result.user, error = null) }
                refreshHome()
            } catch (error: Exception) {
                if (error is CancellationException) throw error
                mutableState.update { it.copy(busy = false, error = userError(error)) }
            }
        }
    }
    fun enterHome() {
        if (state.value.stage == AppStage.ReturningWelcome) mutableState.update { it.copy(stage = AppStage.Home) }
    }
    fun refreshHome() = updateHome(null)
    fun refreshMyPage() {
        if (state.value.busy || session.session.value == null) return
        mutableState.update { it.copy(busy = true, error = null, settingsMessage = null) }
        accountWork = viewModelScope.launch {
            try {
                val profile = session.loadProfile()
                val body = optional { session.loadBodyMeasurements().firstOrNull() }
                val balance = optional { session.loadThreadBalance().availableThreads } ?: state.value.threadBalance
                mutableState.update { it.copy(profile = profile, body = body, threadBalance = balance, busy = false) }
            } catch (error: Exception) {
                if (error is CancellationException) throw error
                mutableState.update { it.copy(busy = false, error = userError(error)) }
            }
        }
    }
    fun saveProfile(displayName: String) {
        if (state.value.busy || displayName.trim().isEmpty()) return
        mutableState.update { it.copy(busy = true, error = null, settingsMessage = null) }
        accountWork = viewModelScope.launch {
            try {
                val profile = session.updateProfile(displayName)
                mutableState.update { it.copy(profile = profile, busy = false, settingsMessage = "프로필을 저장했어요.") }
            } catch (error: Exception) {
                if (error is CancellationException) throw error
                mutableState.update { it.copy(busy = false, error = userError(error)) }
            }
        }
    }
    fun saveBody(heightCm: Double, weightKg: Double) {
        if (state.value.busy || heightCm !in 80.0..250.0 || weightKg !in 20.0..300.0) return
        mutableState.update { it.copy(busy = true, error = null, settingsMessage = null) }
        accountWork = viewModelScope.launch {
            try {
                val body = session.createBodyMeasurement(heightCm, weightKg)
                mutableState.update { it.copy(body = body, busy = false, settingsMessage = "신체 정보를 저장했어요.") }
            } catch (error: Exception) {
                if (error is CancellationException) throw error
                mutableState.update { it.copy(busy = false, error = userError(error)) }
            }
        }
    }
    fun clearSettingsMessage() { mutableState.update { it.copy(error = null, settingsMessage = null) } }
    fun openThreadCharge(activity: Activity? = null) {
        when (state.value.threadCharge.status) {
            ThreadChargeStatus.CheckingReadiness, ThreadChargeStatus.CheckingConsent, ThreadChargeStatus.LoadingAd,
            ThreadChargeStatus.Ready, ThreadChargeStatus.Presenting, ThreadChargeStatus.AwaitingSettlement -> return
            else -> refreshRewardedAdAccess(activity)
        }
    }
    fun retryRewardedAd(activity: Activity? = null) = refreshRewardedAdAccess(activity)

    fun refreshAdPrivacy(activity: Activity?) {
        viewModelScope.launch {
            val privacy = adPrivacy.refreshConsent(activity)
            mutableState.update { it.copy(threadCharge = it.threadCharge.withPrivacy(privacy)) }
        }
    }

    fun showAdPrivacyOptions(activity: Activity?) {
        viewModelScope.launch {
            val privacy = adPrivacy.showPrivacyOptions(activity)
            mutableState.update { it.copy(threadCharge = it.threadCharge.withPrivacy(privacy)) }
        }
    }

    fun showRewardedAd(activity: Activity) {
        if (!state.value.threadCharge.canWatchAd) return
        rewardBalanceBefore = state.value.threadBalance
        rewardEarned = false
        mutableState.update { it.copy(threadCharge = it.threadCharge.transition(ThreadChargeStatus.Presenting, "광고를 표시하고 있어요.")) }
        rewardedAds.show(activity)
    }

    private fun refreshRewardedAdAccess(activity: Activity?) {
        rewardAccessWork?.cancel()
        rewardWork?.cancel()
        rewardedAds.clear()
        if (session.session.value == null) {
            mutableState.update { it.copy(threadCharge = it.threadCharge.transition(ThreadChargeStatus.Failed, "광고 보상은 로그인 후 받을 수 있어요.", false)) }
            return
        }
        mutableState.update { it.copy(threadCharge = it.threadCharge.transition(ThreadChargeStatus.CheckingReadiness, "충전 기능을 확인하고 있어요.", false)) }
        rewardAccessWork = viewModelScope.launch {
            val readiness = try {
                session.loadMonetizationReadiness()
            } catch (error: Exception) {
                if (error is CancellationException) throw error
                mutableState.update { it.copy(threadCharge = it.threadCharge.transition(ThreadChargeStatus.Failed, "충전 기능을 확인할 수 없어요. 다시 시도해 주세요.", false)) }
                return@launch
            }
            if (!readiness.rewardedAdsEnabled) {
                mutableState.update { it.copy(threadCharge = it.threadCharge.transition(ThreadChargeStatus.Disabled, "광고 충전은 아직 준비 중이에요.", false)) }
                return@launch
            }
            mutableState.update { it.copy(threadCharge = it.threadCharge.transition(ThreadChargeStatus.CheckingConsent, "광고 개인정보 설정을 확인하고 있어요.", true)) }
            val privacy = adPrivacy.refreshConsent(activity)
            mutableState.update { it.copy(threadCharge = it.threadCharge.withPrivacy(privacy)) }
            if (!privacy.canRequestAds) {
                mutableState.update { it.copy(threadCharge = it.threadCharge.transition(ThreadChargeStatus.Failed, "광고 개인정보 확인이 필요해요. 설정에서 다시 시도해 주세요.", true)) }
                return@launch
            }
            prepareRewardedAd()
        }
    }

    private fun prepareRewardedAd(message: String = "광고를 준비하고 있어요.") {
        rewardWork?.cancel()
        if (session.session.value == null) {
            mutableState.update { it.copy(threadCharge = it.threadCharge.transition(ThreadChargeStatus.Failed, "광고 보상은 로그인 후 받을 수 있어요.", false)) }
            return
        }
        if (!state.value.threadCharge.rewardedAdsEnabled) {
            mutableState.update { it.copy(threadCharge = it.threadCharge.transition(ThreadChargeStatus.Disabled, "광고 충전은 아직 준비 중이에요.", false)) }
            return
        }
        if (!rewardedAds.isAvailable) {
            mutableState.update { it.copy(threadCharge = it.threadCharge.transition(ThreadChargeStatus.Disabled, "광고 보상은 현재 준비 중이에요.")) }
            return
        }
        val token = ++rewardAttemptToken
        mutableState.update { it.copy(threadCharge = it.threadCharge.transition(ThreadChargeStatus.LoadingAd, message)) }
        rewardWork = viewModelScope.launch {
            try {
                val attempt = session.createThreadRewardAttempt()
                if (token != rewardAttemptToken) return@launch
                rewardedAds.prepare(attempt.attemptId, rewardedAdCallbacks(token))
            } catch (error: Exception) {
                if (error is CancellationException) throw error
                if (token == rewardAttemptToken) rewardFailed("광고를 준비하지 못했어요. 잠시 후 다시 시도해 주세요.")
            }
        }
    }
    private fun rewardedAdCallbacks(token: Long) = RewardedAdCallbacks(
        onReady = {
            if (token == rewardAttemptToken) mutableState.update { it.copy(threadCharge = it.threadCharge.transition(ThreadChargeStatus.Ready)) }
        },
        onRewarded = {
            if (token == rewardAttemptToken) {
                rewardEarned = true
                mutableState.update { it.copy(threadCharge = it.threadCharge.transition(ThreadChargeStatus.AwaitingSettlement, "실타래 지급을 확인하고 있어요.")) }
                settleReward(token)
            }
        },
        onDismissed = { earnedReward ->
            if (token == rewardAttemptToken && !earnedReward && !rewardEarned) {
                rewardFailed("광고를 끝까지 시청한 뒤 다시 시도해 주세요.")
            }
        },
        onFailure = {
            if (token == rewardAttemptToken) rewardFailed(it)
        },
    )
    private fun settleReward(token: Long) {
        rewardWork?.cancel()
        rewardWork = viewModelScope.launch {
            repeat(8) {
                delay(2_000)
                val updatedBalance = try { session.loadThreadBalance().availableThreads }
                catch (error: Exception) { if (error is CancellationException) throw error; null }
                if (token != rewardAttemptToken) return@launch
                if (updatedBalance != null && updatedBalance > rewardBalanceBefore) {
                    mutableState.update { it.copy(threadBalance = updatedBalance) }
                    prepareRewardedAd("실타래가 충전됐어요. 다음 광고를 준비하고 있어요.")
                    return@launch
                }
            }
            if (token == rewardAttemptToken) rewardFailed("실타래 지급 확인이 지연되고 있어요. 잠시 뒤 다시 시도해 주세요.")
        }
    }
    private fun rewardFailed(message: String) {
        rewardedAds.clear()
        mutableState.update { it.copy(threadCharge = it.threadCharge.transition(ThreadChargeStatus.Failed, message)) }
    }
    fun saveReferences(ids: Set<String>) = updateHome(ids)
    private fun updateHome(ids: Set<String>?) {
        val token = session.session.value?.accessToken ?: return
        if (state.value.home.saving) return
        homeWork?.cancel()
        val current = generation
        mutableState.update { it.copy(home = it.home.copy(loading = ids == null, saving = ids != null, error = null)) }
        homeWork = viewModelScope.launch {
            try {
                val snapshot = if (ids == null) homeRepository.load(token) else homeRepository.saveSelection(token, ids)
                if (generation == current) mutableState.update { it.copy(home = HomeUiState(snapshot = snapshot)) }
            } catch (error: Exception) {
                if (error is CancellationException) throw error
                if (generation == current) mutableState.update { it.copy(home = it.home.copy(loading = false, saving = false, error = userError(error))) }
            }
        }
    }
    fun logout(clearProvider: suspend () -> Unit = {}) {
        accountWork?.cancel(); homeWork?.cancel(); rewardWork?.cancel(); rewardAccessWork?.cancel(); rewardedAds.clear(); generation++; providerAttempt++; rewardAttemptToken++
        mutableState.update { it.copy(busy = true, error = null) }
        accountWork = viewModelScope.launch {
            try {
                session.logout()
                signedOut()
                try { clearProvider() } catch (error: Exception) { if (error is CancellationException) throw error }
            } catch (error: Exception) {
                if (error is CancellationException) throw error
                mutableState.update { it.copy(busy = false, error = "로그아웃하지 못했어요. 다시 시도해 주세요.") }
            }
        }
    }
    fun deleteAccount(clearProvider: suspend () -> Unit = {}) {
        if (state.value.busy) return
        accountWork?.cancel(); homeWork?.cancel(); rewardWork?.cancel(); rewardAccessWork?.cancel(); rewardedAds.clear(); generation++; providerAttempt++; rewardAttemptToken++
        mutableState.update { it.copy(busy = true, error = null, settingsMessage = null) }
        accountWork = viewModelScope.launch {
            try {
                session.deleteAccount()
                signedOut()
                try { clearProvider() } catch (error: Exception) { if (error is CancellationException) throw error }
            } catch (error: Exception) {
                if (error is CancellationException) throw error
                mutableState.update { it.copy(busy = false, error = userError(error)) }
            }
        }
    }
    private suspend fun <T> optional(block: suspend () -> T): T? = try { block() }
    catch (error: Exception) { if (error is CancellationException) throw error; null }
}

internal fun userError(error: Exception): String = when (error) {
    is SignInUnavailable -> error.message ?: "로그인할 수 없어요. 다시 시도해 주세요."
    is HttpException -> when (error.code()) {
        401, 403 -> "로그인 정보를 확인할 수 없어요. 다시 로그인해 주세요."
        400, 422 -> "입력 정보를 확인해 주세요."
        429 -> "요청이 많아요. 잠시 후 다시 시도해 주세요."
        else -> "서버에 연결하지 못했어요. 잠시 후 다시 시도해 주세요."
    }
    else -> "처리하지 못했어요.\n연결을 확인하고 다시 시도해 주세요."
}
