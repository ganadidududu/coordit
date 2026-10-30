package com.inseong.coordit.ui.app

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import kotlinx.coroutines.launch
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.compose.currentBackStackEntryAsState
import com.inseong.coordit.ui.auth.AuthenticationScreen
import com.inseong.coordit.ui.components.*
import com.inseong.coordit.ui.home.HomeScreen
import com.inseong.coordit.ui.onboarding.OnboardingScreen
import com.inseong.coordit.ui.mypage.MyPageScreen
import com.inseong.coordit.ui.screens.SplashPresentation
import com.inseong.coordit.ui.screens.SplashScreen
import com.inseong.coordit.ui.theme.*

@Composable
fun CoorditApp(model: AppViewModel, reduceMotion: Boolean, onGoogle: () -> Unit, onLogout: () -> Unit, onDeleteAccount: () -> Unit = {}, closetModel: com.inseong.coordit.ui.closet.ClosetViewModel? = null, fitLabModel: com.inseong.coordit.ui.fitlab.FitLabViewModel? = null, sharedProductUrl: String? = null, onSharedProductConsumed: () -> Unit = {}) {
    val state by model.state.collectAsStateWithLifecycle()
    val photoContext = LocalContext.current
    val photos = remember(state.userId) { com.inseong.coordit.ui.closet.ClosetPhotos(photoContext.applicationContext, state.userId) }
    val nav = rememberNavController()
    val scope = rememberCoroutineScope()
    val route by nav.currentBackStackEntryAsState()
    var navigatedStage by rememberSaveable { mutableStateOf<AppStage?>(null) }
    var accountVisible by rememberSaveable { mutableStateOf(false) }
    var rechargeFromFitLab by rememberSaveable { mutableStateOf(false) }
    LaunchedEffect(accountVisible) { if (!accountVisible) rechargeFromFitLab = false }
    var unavailableFeature by remember { mutableStateOf<String?>(null) }
    var registeringReference by rememberSaveable { mutableStateOf(false) }
    val fitLabState = fitLabModel?.state?.collectAsStateWithLifecycle()?.value
    val context = LocalContext.current
    val guidancePreferences = remember { context.getSharedPreferences("coordit-first-use-guidance-v2", android.content.Context.MODE_PRIVATE) }
    var practice by rememberSaveable(state.profile?.id) { mutableStateOf<com.inseong.coordit.ui.guidance.UsageGuide?>(null) }
    var referencePractice by rememberSaveable(state.profile?.id) { mutableStateOf(false) }
    fun markPracticed(guide: com.inseong.coordit.ui.guidance.UsageGuide) {
        state.profile?.id?.let { guidancePreferences.edit().putBoolean("$it.${guide.name}", true).apply() }
    }
    fun needsPractice(guide: com.inseong.coordit.ui.guidance.UsageGuide): Boolean = state.profile?.id?.let {
        !guidancePreferences.getBoolean("$it.${guide.name}", false)
    } == true
    fun finishPractice() {
        practice?.let(::markPracticed)
        practice = null
    }
    fun finishClosetPractice(completed: Boolean) {
        if (referencePractice) {
            referencePractice = false
            registeringReference = false
            markPracticed(com.inseong.coordit.ui.guidance.UsageGuide.Closet)
            if (completed) fitLabModel?.registerExampleReference()
            nav.navigate("FitLab") { popUpTo(AppStage.Home.name); launchSingleTop = true }
        } else finishPractice()
    }
    val closetState = closetModel?.state?.collectAsStateWithLifecycle()?.value
    LaunchedEffect(state.stage, state.profile?.id, fitLabState?.accountReady, route?.destination?.route, accountVisible, fitLabState?.busy, closetState?.busy, practice) {
        if (state.stage != AppStage.Home) { practice = null; referencePractice = false; registeringReference = false; return@LaunchedEffect }
        if (accountVisible || practice != null || referencePractice) return@LaunchedEffect
        when (route?.destination?.route) {
            "FitLab" -> if (fitLabModel != null && fitLabState?.accountReady == true && fitLabState.busy == false && fitLabState.screen !in setOf(com.inseong.coordit.data.fitlab.FitLabScreen.Loading, com.inseong.coordit.data.fitlab.FitLabScreen.Result, com.inseong.coordit.data.fitlab.FitLabScreen.HistoryDetail) && needsPractice(com.inseong.coordit.ui.guidance.UsageGuide.FitLab)) {
                if (fitLabModel.beginExample()) practice = com.inseong.coordit.ui.guidance.UsageGuide.FitLab
            }
            "Closet" -> if (closetModel != null && closetState?.busy == false && needsPractice(com.inseong.coordit.ui.guidance.UsageGuide.Closet)) {
                if (closetModel.beginExample()) practice = com.inseong.coordit.ui.guidance.UsageGuide.Closet
            }
        }
    }
    LaunchedEffect(state.stage, fitLabState?.accountReady, route?.destination?.route, accountVisible, sharedProductUrl, fitLabState?.busy, fitLabState?.draft?.isExample, practice) {
        if (state.stage == AppStage.Home && !accountVisible && sharedProductUrl != null && fitLabModel != null && fitLabState?.accountReady == true && fitLabState.busy == false && practice == null) {
            if (needsPractice(com.inseong.coordit.ui.guidance.UsageGuide.FitLab)) {
                nav.navigate("FitLab") { popUpTo(AppStage.Home.name); launchSingleTop = true }
            } else {
                scope.launch {
                    if (fitLabModel.importSharedProduct(sharedProductUrl)) {
                        nav.navigate("FitLab") { popUpTo(AppStage.Home.name); launchSingleTop = true }
                        onSharedProductConsumed()
                    }
                }
            }
        }
    }
    LaunchedEffect(state.stage) {
        if (navigatedStage == state.stage) return@LaunchedEffect
        navigatedStage = state.stage
        if (state.stage == AppStage.Authentication || state.stage == AppStage.Welcome) photos.clear()
        accountVisible = false
        unavailableFeature = null
        val destination = if (state.stage == AppStage.Home) when (practice) {
            com.inseong.coordit.ui.guidance.UsageGuide.FitLab, com.inseong.coordit.ui.guidance.UsageGuide.References -> "FitLab"
            com.inseong.coordit.ui.guidance.UsageGuide.Closet -> "Closet"
            null -> state.stage.name
        } else state.stage.name
        nav.navigate(destination) {
            popUpTo(nav.graph.id) { inclusive = true }
            launchSingleTop = true
        }
    }
    NavHost(navController = nav, startDestination = AppStage.Restoring.name) {
        composable(AppStage.Restoring.name) { AccountStatus("로그인 상태를 확인하고 있어요.") }
        composable(AppStage.LoadingAccount.name) { AccountStatus("내 정보를 불러오고 있어요.") }
        composable(AppStage.Welcome.name) {
            SplashScreen(SplashPresentation.FirstInstall, model::openAuthentication, {}, reduceMotion = reduceMotion)
        }
        composable(AppStage.Authentication.name) {
            AuthenticationScreen(
                busy = state.busy,
                error = state.error,
                onGoogle = onGoogle,
                onApple = model::appleUnavailable,
                onGuest = model::loginGuest,
                onEmail = model::loginEmail,
                onDismiss = model::backToWelcome,
            )
        }
        composable(AppStage.AccountRecovery.name) {
            AccountStatus(state.error ?: "계정 정보를 불러오지 못했어요.", model::retryAccount, onLogout, state.busy)
        }
        composable(AppStage.Onboarding.name) {
            OnboardingScreen(state.profile, state.body, state.busy, state.error, model::completeOnboarding, onLogout)
        }
        composable(AppStage.ReturningWelcome.name) {
            SplashScreen(SplashPresentation.ReturningUser, {}, model::enterHome, reduceMotion = reduceMotion)
        }
        composable(AppStage.Home.name) {
            HomeScreen(state.home, model::refreshHome, model::saveReferences,
                onCloset = { if (closetModel != null) { closetModel.load(); nav.navigate("Closet") } else unavailableFeature = "옷장" },
                onFitLab = { if (fitLabModel != null) { fitLabModel.open(); nav.navigate("FitLab") } else unavailableFeature = "FIT LAB" },
                onProfile = { accountVisible = true },
                history = fitLabState?.history.orEmpty(),
                onOpenHistory = { snapshot -> fitLabModel?.openHistory(snapshot); nav.navigate("FitLab") { launchSingleTop = true } },
                reduceMotion = reduceMotion,
                onAddGarment = { closetModel?.startAdd(); nav.navigate("Closet") { launchSingleTop = true } })
        }
        composable("Closet") {
            closetModel?.let { closet -> com.inseong.coordit.ui.closet.ClosetScreen(closet, photos,
                onHome = { nav.popBackStack(); model.refreshHome() },
                onProfile = { accountVisible = true },
                onFitLab = { if (fitLabModel != null) { if (registeringReference) fitLabModel.loadReferences() else fitLabModel.open(); registeringReference = false; nav.navigate("FitLab") { popUpTo(AppStage.Home.name); launchSingleTop = true } } else unavailableFeature = "FIT LAB" },
                returningToFitLab = registeringReference, onExampleFinished = ::finishClosetPractice, referencePractice = referencePractice,
                onReferenceRegistered = { reference ->
                    if (fitLabModel?.acceptRegisteredReference(reference) == true) {
                        closet.consumeRegisteredFitLabReference()
                        registeringReference = false
                        nav.navigate("FitLab") { popUpTo(AppStage.Home.name); launchSingleTop = true }
                    } else closet.error("상품과 같은 종류의 기준 옷을 선택해주세요. 등록한 옷은 옷장에 저장되어 있어요.")
                },
                onStartExample = { if (closet.beginExample()) practice = com.inseong.coordit.ui.guidance.UsageGuide.Closet }) }
        }
        composable("FitLab") {
            fitLabModel?.let { fitLab -> com.inseong.coordit.ui.fitlab.FitLabScreen(
                fitLab,
                onHome = { nav.popBackStack(AppStage.Home.name, inclusive = false); model.refreshHome() },
                onCloset = {
                    if (closetModel != null) {
                        closetModel.load()
                        nav.navigate("Closet") { popUpTo(AppStage.Home.name) }
                    } else unavailableFeature = "옷장"
                },
                onProfile = { accountVisible = true },
                onRegisterReference = {
                    if (closetModel != null) {
                        if (fitLab.state.value.draft.isExample) {
                            if (closetModel.beginExample()) {
                                referencePractice = true
                                nav.navigate("Closet") { launchSingleTop = true }
                            }
                        } else {
                            registeringReference = true
                            closetModel.startReferenceRegistration()
                            nav.navigate("Closet") { launchSingleTop = true }
                        }
                    }
                },
                onExampleFinished = ::finishPractice,
                onRecharge = { rechargeFromFitLab = true; accountVisible = true },
                onStartExample = { if (fitLab.beginExample()) practice = com.inseong.coordit.ui.guidance.UsageGuide.FitLab },
            ) }
        }
    }
    if (!accountVisible && practice == null && state.stage == AppStage.Home && route?.destination?.route != "FitLab" && fitLabState?.draft?.isExample == false) {
        fitLabState.notice?.let { notice ->
            com.inseong.coordit.ui.fitlab.FitAnalysisNotice(notice, reduceMotion,
                onDismiss = { fitLabModel?.dismissNotice() },
                onOpen = { fitLabModel?.dismissNotice(); nav.navigate("FitLab") { launchSingleTop = true } })
        }
    }
    if (accountVisible) {
        MyPageScreen(state.profile, state.body, state.threadBalance, state.threadCharge, state.busy, state.error, state.settingsMessage,
            onBack = { accountVisible = false; rechargeFromFitLab = false; fitLabModel?.updateBalance(state.threadBalance) },
            onHome = { accountVisible = false; nav.navigate(AppStage.Home.name) { popUpTo(AppStage.Home.name); launchSingleTop = true }; model.refreshHome() },
            onCloset = { accountVisible = false; closetModel?.load(); nav.navigate("Closet") { popUpTo(AppStage.Home.name) } },
            onFitLab = { accountVisible = false; fitLabModel?.open(); nav.navigate("FitLab") { popUpTo(AppStage.Home.name) } },
            onRefresh = model::refreshMyPage, onOpenThreadCharge = model::openThreadCharge, onShowRewardedAd = model::showRewardedAd, onRetryRewardedAd = model::retryRewardedAd,
            onRefreshAdPrivacy = model::refreshAdPrivacy, onShowAdPrivacyOptions = model::showAdPrivacyOptions,
            onSaveProfile = model::saveProfile, onSaveBody = model::saveBody,
            onLogout = onLogout, onDeleteAccount = onDeleteAccount, onClearMessage = model::clearSettingsMessage,
            initiallyShowThreadCharge = rechargeFromFitLab, feedbackConsent = state.feedbackConsent,
            onRefreshFeedbackConsent = model::refreshFeedbackConsent, onSaveFeedbackConsent = model::saveFeedbackConsent)
    }
    unavailableFeature?.let { feature ->
        Dialog(onDismissRequest = { unavailableFeature = null }) {
            Column(Modifier.fillMaxWidth().background(AppColors.panel, ContinuousRoundedShape(11.dp)).padding(24.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)) {
                CoorditText(feature, CoorditTypography.gmarketBold(20f))
                CoorditText("이 기능은 준비 중이에요.", CoorditTypography.gmarketMedium(14f))
                CoorditButton("확인", { unavailableFeature = null })
            }
        }
    }
}

@Composable
private fun AccountStatus(message: String, onRetry: (() -> Unit)? = null, onLogout: (() -> Unit)? = null, busy: Boolean = false) {
    BoxWithConstraints(Modifier.fillMaxSize().testTag("account-status")) {
        SharedAppBackground(maxWidth.value / 402f)
        Column(Modifier.align(Alignment.Center).fillMaxWidth().padding(28.dp).verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(18.dp)) {
            CoorditText(message, CoorditTypography.gmarketMedium(16f).copy(lineBreak = CoorditTypography.koreanParagraph, localeList = CoorditTypography.koreanLocale), Modifier.semantics { liveRegion = LiveRegionMode.Polite })
            onRetry?.let { CoorditButton("다시 시도", it, enabled = !busy) }
            onLogout?.let { CoorditButton("다시 로그인", it, secondary = true, enabled = !busy) }
        }
    }
}
