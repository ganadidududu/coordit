package com.inseong.coordit.data.remote

import com.inseong.coordit.data.model.*
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.Header
import retrofit2.http.POST
import retrofit2.http.PATCH
import retrofit2.http.DELETE

interface CoorditApi {
    @GET("health") suspend fun health(): BackendHealth
    @POST("auth/google") suspend fun loginGoogle(@Body request: SocialAuthRequest): AuthSession
    @POST("auth/apple") suspend fun loginApple(@Body request: SocialAuthRequest): AuthSession
    @POST("auth/refresh") suspend fun refresh(@Body request: RefreshAuthRequest): AuthSession
    @GET("users/me") suspend fun me(@Header("Authorization") authorization: String): UserProfile
    @PATCH("users/me") suspend fun updateMe(@Header("Authorization") authorization: String, @Body request: UpdateProfileRequest): UserProfile
    @DELETE("users/me") suspend fun deleteMe(@Header("Authorization") authorization: String)
    @GET("auth/onboarding/status") suspend fun onboardingStatus(@Header("Authorization") authorization: String): OnboardingStatus
    @POST("auth/onboarding") suspend fun completeOnboarding(@Header("Authorization") authorization: String, @Body request: OnboardingRequest): OnboardingCompletion
    @GET("body-measurements") suspend fun bodyMeasurements(@Header("Authorization") authorization: String): List<BodyMeasurement>
    @POST("body-measurements") suspend fun createBodyMeasurement(@Header("Authorization") authorization: String, @Body request: BodyMeasurementRequest): BodyMeasurement
    @GET("thread-wallet/balance") suspend fun threadBalance(@Header("Authorization") authorization: String): ThreadBalanceResponse
}
