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
import com.google.gson.JsonParser
import java.util.Base64

class SessionRepository(private val api: CoorditApi, private val store: SessionStore) {
    private val mutableSession = MutableStateFlow<AuthSession?>(null)
    val session: StateFlow<AuthSession?> = mutableSession.asStateFlow()
    private val sessionMutation = Mutex()

    suspend fun restore(): AuthSession? = sessionMutation.withLock {
        val saved = store.read() ?: return@withLock null
        val expiration = tokenExpiration(saved.accessToken)
        if (expiration != null && expiration > System.currentTimeMillis() / 1000 + 5 * 60) {
            mutableSession.value = saved
            return@withLock saved
        }
        val refreshed = try {
            api.refresh(RefreshAuthRequest(saved.refreshToken))
        } catch (error: HttpException) {
            if (error.code() in setOf(401, 403)) {
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
    suspend fun loginEmail(email: String, password: String): AuthSession = sessionMutation.withLock {
        require(email.isNotBlank() && password.isNotBlank())
        persist(api.loginEmail(EmailAuthRequest(email.trim(), password)))
    }
    suspend fun loginGuest(): AuthSession = sessionMutation.withLock { persist(api.loginGuest()) }
    suspend fun logout() = sessionMutation.withLock { store.clear(); mutableSession.value = null }
    suspend fun health(): BackendHealth = api.health()
    suspend fun loadProfile(): UserProfile = api.me(authorization())
    suspend fun updateProfile(displayName: String): UserProfile = api.updateMe(authorization(), UpdateProfileRequest(displayName.trim()))
    suspend fun loadOnboardingStatus(): OnboardingStatus = api.onboardingStatus(authorization())
    suspend fun completeOnboarding(request: OnboardingRequest): OnboardingCompletion = api.completeOnboarding(authorization(), request)
    suspend fun loadThreadBalance(): ThreadBalanceResponse = api.threadBalance(authorization())
    suspend fun loadMonetizationReadiness(): MonetizationReadiness = api.monetizationReadiness(authorization())
    suspend fun createThreadRewardAttempt(): ThreadRewardAttempt = api.createThreadRewardAttempt(authorization())
    suspend fun loadBodyMeasurements(): List<BodyMeasurement> = api.bodyMeasurements(authorization())
    suspend fun createBodyMeasurement(heightCm: Double, weightKg: Double): BodyMeasurement =
        api.createBodyMeasurement(authorization(), BodyMeasurementRequest(heightCm, weightKg))
    suspend fun deleteAccount() = sessionMutation.withLock {
        api.deleteMe(authorization())
        store.clear()
        mutableSession.value = null
    }

    private fun authorization(): String = "Bearer ${checkNotNull(session.value) { "Sign in required" }.accessToken}"
    private fun tokenExpiration(token: String): Long? = runCatching {
        val segments = token.split('.')
        if (segments.size != 3) return@runCatching null
        val payload = String(Base64.getUrlDecoder().decode(segments[1]), Charsets.UTF_8)
        val exp = JsonParser.parseString(payload).asJsonObject.get("exp")
        if (exp == null || !exp.isJsonPrimitive || !exp.asJsonPrimitive.isNumber) null else exp.asLong
    }.getOrNull()
    private suspend fun persist(value: AuthSession): AuthSession {
        if (!value.isValid()) throw IOException("Invalid authentication response")
        store.write(value)
        mutableSession.value = value
        return value
    }
}
