package com.inseong.coordit.data.model

import com.google.gson.annotations.SerializedName

data class AuthSession(val accessToken: String, val refreshToken: String, val user: AuthUser) {
    fun isValid(): Boolean = accessToken.isNotBlank() && refreshToken.isNotBlank() && user.id.isNotBlank()
    override fun toString(): String = "AuthSession(redacted)"
}
data class AuthUser(
    val id: String,
    val email: String,
    @SerializedName("isAnonymous") val isAnonymous: Boolean = false,
)
data class UserProfile(
    val id: String,
    val email: String,
    @SerializedName("display_name") val displayName: String? = null,
    val gender: String? = null,
    @SerializedName("birth_date") val birthDate: String? = null,
    @SerializedName("birth_year") val birthYear: Int? = null,
    @SerializedName("created_at") val createdAt: String? = null,
    @SerializedName("updated_at") val updatedAt: String? = null,
)
data class BodyMeasurement(
    val id: String? = null,
    @SerializedName("height_cm") val heightCm: Double? = null,
    @SerializedName("weight_kg") val weightKg: Double? = null,
    @SerializedName("shoulder_width") val shoulderWidth: Double? = null,
    @SerializedName("chest_circumference") val chestCircumference: Double? = null,
    @SerializedName("waist_circumference") val waistCircumference: Double? = null,
    @SerializedName("hip_circumference") val hipCircumference: Double? = null,
    val outseam: Double? = null,
    @SerializedName("created_at") val createdAt: String? = null,
)
data class OnboardingStatus(val onboardingComplete: Boolean)
data class OnboardingCompletion(val onboardingComplete: Boolean, val user: UserProfile, val bodyMeasurementsSaved: Boolean)
data class OnboardingRequest(
    val displayName: String,
    val gender: String? = null,
    val birthDate: String? = null,
    val bodyMeasurements: Measurements = Measurements(),
    val consents: Map<String, Consent>,
) {
    data class Measurements(val heightCm: Double? = null, val weightKg: Double? = null)
    data class Consent(val accepted: Boolean, val version: String)
}
data class BackendHealth(val ok: Boolean, val service: String)
data class ThreadBalanceResponse(val availableThreads: Int)
data class MonetizationReadiness(
    val rewardedAdsEnabled: Boolean,
    val iapEnabled: Boolean,
)
data class ThreadRewardAttempt(
    val attemptId: String,
    val expiresAt: String,
    val status: String,
)
data class UpdateProfileRequest(val displayName: String)
data class BodyMeasurementRequest(
    val heightCm: Double,
    val weightKg: Double,
    val rawData: Map<String, String> = mapOf("source" to "android-mypage"),
)
data class BackendErrorResponse(val message: String)
data class SocialAuthRequest(val idToken: String, val nonce: String) {
    override fun toString(): String = "SocialAuthRequest(redacted)"
}
data class EmailAuthRequest(val email: String, val password: String) {
    override fun toString(): String = "EmailAuthRequest(redacted)"
}
data class RefreshAuthRequest(val refreshToken: String) {
    override fun toString(): String = "RefreshAuthRequest(redacted)"
}
