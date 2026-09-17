package com.inseong.coordit.ui.app

import androidx.activity.compose.BackHandler
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

@Composable
fun CoorditApp(model: AppViewModel, reduceMotion: Boolean, onGoogle: () -> Unit, onLogout: () -> Unit, onDeleteAccount: () -> Unit = {}, closetModel: com.inseong.coordit.ui.closet.ClosetViewModel? = null, fitLabModel: com.inseong.coordit.ui.fitlab.FitLabViewModel? = null) {
    val state by model.state.collectAsStateWithLifecycle()
    val photos = remember { com.inseong.coordit.ui.closet.ClosetPhotos() }
    val nav = rememberNavController()
    var accountVisible by remember { mutableStateOf(false) }
    var unavailableFeature by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(state.stage) {
        if (state.stage == AppStage.Authentication || state.stage == AppStage.Welcome) photos.clear()
        accountVisible = false
        unavailableFeature = null
        nav.navigate(state.stage.name) {
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
            BackHandler(enabled = !state.busy) { model.backToWelcome() }
            AuthenticationScreen(state.busy, state.error, onGoogle, model::appleUnavailable)
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
                onProfile = { accountVisible = true })
        }
        composable("Closet") {
            closetModel?.let { closet -> com.inseong.coordit.ui.closet.ClosetScreen(closet, photos,
                onHome = { nav.popBackStack(); model.refreshHome() },
                onProfile = { accountVisible = true },
                onFitLab = { if (fitLabModel != null) { fitLabModel.open(); nav.navigate("FitLab") } else unavailableFeature = "FIT LAB" }) }
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
            ) }
        }
    }
    if (accountVisible) {
        MyPageScreen(state.profile, state.body, state.threadBalance, state.busy, state.error, state.settingsMessage,
            onBack = { accountVisible = false },
            onHome = { accountVisible = false; nav.navigate(AppStage.Home.name) { popUpTo(AppStage.Home.name); launchSingleTop = true }; model.refreshHome() },
            onCloset = { accountVisible = false; closetModel?.load(); nav.navigate("Closet") { popUpTo(AppStage.Home.name) } },
            onFitLab = { accountVisible = false; fitLabModel?.open(); nav.navigate("FitLab") { popUpTo(AppStage.Home.name) } },
            onRefresh = model::refreshMyPage, onSaveProfile = model::saveProfile, onSaveBody = model::saveBody,
            onLogout = onLogout, onDeleteAccount = onDeleteAccount, onClearMessage = model::clearSettingsMessage)
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
