package com.inseong.coordit.ui.threadcharge

import android.app.Activity
import android.content.Context
import com.google.android.gms.ads.AdError
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.FullScreenContentCallback
import com.google.android.gms.ads.MobileAds
import com.google.android.gms.ads.rewarded.RewardedAd
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback
import com.google.android.gms.ads.rewarded.ServerSideVerificationOptions
import com.inseong.coordit.BuildConfig

interface RewardedAdGateway {
    val isAvailable: Boolean
    fun prepare(customData: String, callbacks: RewardedAdCallbacks)
    fun show(activity: Activity)
    fun clear()
}

data class RewardedAdCallbacks(
    val onReady: () -> Unit,
    val onRewarded: () -> Unit,
    val onDismissed: (earnedReward: Boolean) -> Unit,
    val onFailure: (String) -> Unit,
)

class GoogleRewardedAdGateway(context: Context) : RewardedAdGateway {
    private val appContext = context.applicationContext
    private var rewardedAd: RewardedAd? = null
    private var callbacks: RewardedAdCallbacks? = null
    private var requestToken = 0L
    private var initialized = false
    private var initializing = false
    private var pendingInitializationToken = 0L
    private var pendingInitializationCustomData = ""

    override val isAvailable: Boolean
        get() = BuildConfig.ADMOB_REWARDED_ENABLED && BuildConfig.ADMOB_REWARDED_AD_UNIT_ID.isNotBlank()

    override fun prepare(customData: String, callbacks: RewardedAdCallbacks) {
        clear()
        if (!isAvailable) {
            callbacks.onFailure("광고 보상은 현재 준비 중이에요.")
            return
        }
        this.callbacks = callbacks
        val token = ++requestToken
        if (initialized) {
            load(token, customData)
            return
        }
        pendingInitializationToken = token
        pendingInitializationCustomData = customData
        if (initializing) return
        initializing = true
        MobileAds.initialize(appContext) {
            initialized = true
            initializing = false
            if (pendingInitializationToken == requestToken) load(requestToken, pendingInitializationCustomData)
        }
    }

    override fun show(activity: Activity) {
        val ad = rewardedAd
        val callback = callbacks
        if (ad == null || callback == null) {
            callback?.onFailure("광고를 준비하지 못했어요. 다시 시도해 주세요.")
            return
        }
        rewardedAd = null
        val token = requestToken
        var earnedReward = false
        ad.fullScreenContentCallback = object : FullScreenContentCallback() {
            override fun onAdDismissedFullScreenContent() {
                if (token == requestToken) callback.onDismissed(earnedReward)
            }

            override fun onAdFailedToShowFullScreenContent(adError: AdError) {
                if (token == requestToken) callback.onFailure("광고를 표시하지 못했어요. 잠시 후 다시 시도해 주세요.")
            }
        }
        ad.show(activity) {
            if (token == requestToken) {
                earnedReward = true
                callback.onRewarded()
            }
        }
    }

    override fun clear() {
        rewardedAd = null
        callbacks = null
        requestToken++
    }

    private fun load(token: Long, customData: String) {
        if (token != requestToken || !isAvailable) return
        RewardedAd.load(
            appContext,
            BuildConfig.ADMOB_REWARDED_AD_UNIT_ID,
            AdRequest.Builder().build(),
            object : RewardedAdLoadCallback() {
                override fun onAdLoaded(ad: RewardedAd) {
                    if (token != requestToken) return
                    rewardedAd = ad
                    ad.setServerSideVerificationOptions(
                        ServerSideVerificationOptions.Builder().setCustomData(customData).build(),
                    )
                    callbacks?.onReady()
                }

                override fun onAdFailedToLoad(error: com.google.android.gms.ads.LoadAdError) {
                    if (token == requestToken) callbacks?.onFailure("광고를 준비하지 못했어요. 잠시 후 다시 시도해 주세요.")
                }
            },
        )
    }
}

object DisabledRewardedAdGateway : RewardedAdGateway {
    override val isAvailable = false
    override fun prepare(customData: String, callbacks: RewardedAdCallbacks) = callbacks.onFailure("광고 보상은 현재 준비 중이에요.")
    override fun show(activity: Activity) = Unit
    override fun clear() = Unit
}
