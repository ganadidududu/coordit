package com.inseong.coordit.ui.app

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.inseong.coordit.ui.auth.AuthenticationScreen
import com.inseong.coordit.ui.components.*
import com.inseong.coordit.ui.home.HomeScreen
import com.inseong.coordit.ui.onboarding.OnboardingScreen
import com.inseong.coordit.ui.mypage.MyPageScreen
import com.inseong.coordit.ui.screens.SplashPresentation
import com.inseong.coordit.ui.screens.SplashScreen
import com.inseong.coordit.ui.theme.*
import com.inseong.coordit.data.fitlab.FitLabState
import com.inseong.coordit.data.fitlab.FitLabHistorySnapshot
import com.inseong.coordit.sharing.SharedProductImports
import com.inseong.coordit.ui.fitlab.FitAnalysisNotice
import kotlinx.coroutines.launch

@Composable
fun CoorditApp(model: AppViewModel, reduceMotion: Boolean, onGoogle: () -> Unit, onLogout: () -> Unit, onDeleteAccount: () -> Unit = {}, closetModel: com.inseong.coordit.ui.closet.ClosetViewModel? = null, fitLabModel: com.inseong.coordit.ui.fitlab.FitLabViewModel? = null, sharedImports: SharedProductImports? = null) {
    val state by model.state.collectAsStateWithLifecycle()
    val fitState = fitLabModel?.state?.collectAsStateWithLifecycle()?.value ?: FitLabState()
    val pendingImports = sharedImports?.pending?.collectAsStateWithLifecycle()?.value.orEmpty()
    val context = androidx.compose.ui.platform.LocalContext.current
    val photos = remember(state.userId) { com.inseong.coordit.ui.closet.ClosetPhotos(context.applicationContext, state.userId) }
    val nav = rememberNavController()
    val scope = rememberCoroutineScope()
    var accountVisible by remember { mutableStateOf(false) }
    var unavailableFeature by remember { mutableStateOf<String?>(null) }
    var openThreadCharge by remember { mutableStateOf(false) }
    var pendingShare by remember { mutableStateOf<String?>(null) }
    fun navigateFeature(route: String) {
        accountVisible = false
        nav.navigate(route) { popUpTo(AppStage.Home.name); launchSingleTop = true }
    }
    fun openHistory(snapshot: FitLabHistorySnapshot) {
        fitLabModel?.openHistory(snapshot)
        if (fitLabModel != null && !fitState.busy) navigateFeature("FitLab")
    }
    LaunchedEffect(state.stage) {
        if (state.stage == AppStage.Authentication || state.stage == AppStage.Welcome) photos.clear()
        accountVisible = false
        unavailableFeature = null
        nav.navigate(state.stage.name) {
            popUpTo(nav.graph.id) { inclusive = true }
            launchSingleTop = true
        }
    }
    fun acceptShare(url: String) {
        scope.launch {
        if (fitLabModel?.openSharedProduct(url) == true) {
            navigateFeature("FitLab")
            sharedImports?.consume(url)
            pendingShare = null
        }
        }
    }
    LaunchedEffect(state.stage, pendingImports.firstOrNull(), fitState.busy, fitState.accountReady) {
        if (state.stage == AppStage.Home && !fitState.busy && fitState.accountReady) {
            pendingImports.firstOrNull()?.let { url ->
                if (fitState.draft.productUrl.isNotBlank() || fitState.draft.productName.isNotBlank() || fitState.draft.sizes.any { it.measurements.isNotEmpty() }) pendingShare = url
                else acceptShare(url)
            }
        }
    }
    LaunchedEffect(fitState.needsThreads) {
        if (fitState.needsThreads) {
            openThreadCharge = true
            accountVisible = true
            fitLabModel?.acknowledgeThreadPrompt()
        }
    }
    Box(Modifier.fillMaxSize()) {
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
                onCloset = { if (closetModel != null) { closetModel.load(); navigateFeature("Closet") } else unavailableFeature = "옷장" },
                onFitLab = { if (fitLabModel != null) { fitLabModel.open(); navigateFeature("FitLab") } else unavailableFeature = "FIT LAB" },
                onProfile = { accountVisible = true },
                history = fitState.history,
                onHistory = ::openHistory)
        }
        composable("Closet") {
            closetModel?.let { closet -> com.inseong.coordit.ui.closet.ClosetScreen(closet, photos,
                onHome = { navigateFeature(AppStage.Home.name); model.refreshHome() },
                onProfile = { accountVisible = true },
                onFitLab = { if (fitLabModel != null) { fitLabModel.open(); navigateFeature("FitLab") } else unavailableFeature = "FIT LAB" }) }
        }
        composable("FitLab") {
            fitLabModel?.let { fitLab -> com.inseong.coordit.ui.fitlab.FitLabScreen(
                fitLab,
                onHome = { navigateFeature(AppStage.Home.name); model.refreshHome() },
                onCloset = {
                    if (closetModel != null) {
                        closetModel.load()
                        navigateFeature("Closet")
                    } else unavailableFeature = "옷장"
                },
                onProfile = { accountVisible = true },
                onThreadCharge = { openThreadCharge = true; accountVisible = true },
            ) }
        }
    }
    pendingShare?.let { url ->
        Dialog(onDismissRequest = { sharedImports?.consume(url); pendingShare = null }) {
            Column(Modifier.fillMaxWidth().background(AppColors.panel, ContinuousRoundedShape(11.dp)).padding(24.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                CoorditText("공유한 상품을 불러올까요?", CoorditTypography.gmarketBold(18f))
                CoorditText("현재 입력이나 저장하지 않은 분석 결과를 닫고 공유한 상품 링크를 엽니다.", CoorditTypography.gmarketMedium(13f))
                CoorditButton("상품 링크 열기", { acceptShare(url) }, Modifier.testTag("shared-product-confirm"))
                CoorditButton("현재 입력 유지", { sharedImports?.consume(url); pendingShare = null }, secondary = true)
            }
        }
    }
    if (accountVisible) {
        MyPageScreen(state.profile, state.body, state.threadBalance, state.threadCharge, state.busy, state.error, state.settingsMessage,
            onBack = { accountVisible = false; openThreadCharge = false },
            onHome = { accountVisible = false; nav.navigate(AppStage.Home.name) { popUpTo(AppStage.Home.name); launchSingleTop = true }; model.refreshHome() },
            onCloset = { accountVisible = false; closetModel?.load(); nav.navigate("Closet") { popUpTo(AppStage.Home.name) } },
            onFitLab = { accountVisible = false; fitLabModel?.open(); nav.navigate("FitLab") { popUpTo(AppStage.Home.name) } },
            onRefresh = model::refreshMyPage, onOpenThreadCharge = model::openThreadCharge, onShowRewardedAd = model::showRewardedAd, onRetryRewardedAd = model::retryRewardedAd,
            onRefreshAdPrivacy = model::refreshAdPrivacy, onShowAdPrivacyOptions = model::showAdPrivacyOptions,
            onSaveProfile = model::saveProfile, onSaveBody = model::saveBody,
            onLogout = onLogout, onDeleteAccount = onDeleteAccount, onClearMessage = model::clearSettingsMessage,
            initiallyShowThreadCharge = openThreadCharge)
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
    if (state.stage == AppStage.Home && fitLabModel != null) {
        fitState.notice?.let { notice ->
            FitAnalysisNotice(notice, reduceMotion, onDismiss = fitLabModel::dismissNotice,
                onOpen = { navigateFeature("FitLab"); fitLabModel.dismissNotice() },
                modifier = Modifier.align(Alignment.TopCenter))
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
