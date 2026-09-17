package com.inseong.coordit.data.repository

import com.inseong.coordit.data.local.SessionStore
import com.inseong.coordit.data.model.*
import com.inseong.coordit.data.remote.CoorditApi
import java.io.IOException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import retrofit2.HttpException

class SessionRepository(private val api: CoorditApi, private val store: SessionStore) {
    private val mutableSession = MutableStateFlow<AuthSession?>(null)
    val session: StateFlow<AuthSession?> = mutableSession.asStateFlow()
    private val sessionMutation = Mutex()

    suspend fun restore(): AuthSession? = sessionMutation.withLock {
        val saved = store.read() ?: return@withLock null
        val refreshed = try {
            api.refresh(RefreshAuthRequest(saved.refreshToken))
        } catch (error: HttpException) {
            if (error.code() in setOf(400, 401, 403)) {
                store.clear()
                mutableSession.value = null
            }
            throw error
        }
        persist(refreshed)
    }

    suspend fun loginGoogle(idToken: String, nonce: String): AuthSession = sessionMutation.withLock {
        require(idToken.isNotBlank() && nonce.isNotBlank())
        persist(api.loginGoogle(SocialAuthRequest(idToken, nonce)))
    }
    suspend fun loginApple(idToken: String, nonce: String): AuthSession = sessionMutation.withLock {
        require(idToken.isNotBlank() && nonce.isNotBlank())
        persist(api.loginApple(SocialAuthRequest(idToken, nonce)))
    }
    suspend fun logout() = sessionMutation.withLock { store.clear(); mutableSession.value = null }
    suspend fun health(): BackendHealth = api.health()
    suspend fun loadProfile(): UserProfile = api.me(authorization())
    suspend fun updateProfile(displayName: String): UserProfile = api.updateMe(authorization(), UpdateProfileRequest(displayName.trim()))
    suspend fun loadOnboardingStatus(): OnboardingStatus = api.onboardingStatus(authorization())
    suspend fun completeOnboarding(request: OnboardingRequest): OnboardingCompletion = api.completeOnboarding(authorization(), request)
    suspend fun loadThreadBalance(): ThreadBalanceResponse = api.threadBalance(authorization())
    suspend fun loadBodyMeasurements(): List<BodyMeasurement> = api.bodyMeasurements(authorization())
    suspend fun createBodyMeasurement(heightCm: Double, weightKg: Double): BodyMeasurement =
        api.createBodyMeasurement(authorization(), BodyMeasurementRequest(heightCm, weightKg))
    suspend fun deleteAccount() = sessionMutation.withLock {
        api.deleteMe(authorization())
        store.clear()
        mutableSession.value = null
    }

    private fun authorization(): String = "Bearer ${checkNotNull(session.value) { "Sign in required" }.accessToken}"
    private suspend fun persist(value: AuthSession): AuthSession {
        if (!value.isValid()) throw IOException("Invalid authentication response")
        store.write(value)
        mutableSession.value = value
        return value
    }
}
