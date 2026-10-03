package com.inseong.coordit.ui.threadcharge

import android.app.Activity
import android.content.Context
import com.google.android.ump.ConsentInformation
import com.google.android.ump.ConsentRequestParameters
import com.google.android.ump.UserMessagingPlatform
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume

data class AdPrivacyState(
    val canRequestAds: Boolean = false,
    val privacyOptionsRequired: Boolean = false,
    val statusText: String = "광고 개인정보 설정을 확인하고 있어요.",
)

interface AdPrivacyGateway {
    suspend fun refreshConsent(activity: Activity?): AdPrivacyState
    suspend fun showPrivacyOptions(activity: Activity?): AdPrivacyState
}

class GoogleAdPrivacyGateway(context: Context) : AdPrivacyGateway {
    private val consentInformation = UserMessagingPlatform.getConsentInformation(context.applicationContext)

    override suspend fun refreshConsent(activity: Activity?): AdPrivacyState {
        if (activity == null) return currentState("광고 개인정보 확인이 필요해요.")
        return suspendCancellableCoroutine { continuation ->
            consentInformation.requestConsentInfoUpdate(
                activity,
                ConsentRequestParameters.Builder().build(),
                {
                    UserMessagingPlatform.loadAndShowConsentFormIfRequired(activity) {
                        if (continuation.isActive) continuation.resume(currentState())
                    }
                },
                {
                    if (continuation.isActive) continuation.resume(currentState())
                },
            )
        }
    }

    override suspend fun showPrivacyOptions(activity: Activity?): AdPrivacyState {
        val refreshed = refreshConsent(activity)
        if (!refreshed.canRequestAds || !refreshed.privacyOptionsRequired || activity == null) {
            return if (refreshed.canRequestAds) refreshed.copy(statusText = "현재 지역에서는 추가 선택이 필요하지 않아요.") else refreshed
        }
        return suspendCancellableCoroutine { continuation ->
            UserMessagingPlatform.showPrivacyOptionsForm(activity) { error ->
                if (continuation.isActive) {
                    continuation.resume(
                        currentState(
                            if (error == null) "광고 개인정보 설정이 반영됐어요."
                            else "광고 개인정보 설정을 열지 못했어요. 다시 시도해 주세요.",
                        ),
                    )
                }
            }
        }
    }

    private fun currentState(statusText: String? = null): AdPrivacyState {
        val canRequestAds = consentInformation.canRequestAds()
        val privacyOptionsRequired = consentInformation.privacyOptionsRequirementStatus ==
            ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED
        return AdPrivacyState(
            canRequestAds = canRequestAds,
            privacyOptionsRequired = privacyOptionsRequired,
            statusText = statusText ?: when {
                !canRequestAds -> "광고 개인정보 확인이 필요해요."
                privacyOptionsRequired -> "광고 개인정보 설정을 언제든 변경할 수 있어요."
                else -> "비개인화 광고 설정이 적용되어 있어요."
            },
        )
    }
}

object DisabledAdPrivacyGateway : AdPrivacyGateway {
    private val unavailable = AdPrivacyState(statusText = "광고 개인정보 확인이 필요해요.")
    override suspend fun refreshConsent(activity: Activity?) = unavailable
    override suspend fun showPrivacyOptions(activity: Activity?) = unavailable
}
