package com.inseong.coordit.ui.mypage

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.widget.Toast
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.app.NotificationManagerCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.inseong.coordit.BuildConfig
import com.inseong.coordit.R
import com.inseong.coordit.data.model.BodyMeasurement
import com.inseong.coordit.data.model.UserProfile
import com.inseong.coordit.ui.app.ThreadChargeState
import com.inseong.coordit.ui.app.ThreadChargeStatus
import com.inseong.coordit.ui.components.*
import com.inseong.coordit.ui.theme.*
import java.text.DecimalFormat

private enum class Page(val title: String) {
    Root("MY PAGE"), Account("계정"), Profile("프로필 수정"), Password("비밀번호 변경"), Logout("로그아웃"),
    Delete("회원 탈퇴"), Body("내 신체 정보"), BodyEdit("신체 정보 수정"), Notifications("알림"),
    Privacy("개인정보/보안"), Policy("개인정보 처리방침"), Terms("서비스 이용약관"), Settings("앱 설정"),
    ThreadCharge("실타래 충전")
}

private object MyPageDesign {
    const val designWidth = 402f

    object Shell {
        const val contentTop = 115f
        const val contentBottom = 118f
        const val sectionSpacing = 18f
        const val standardContentWidth = 370f
        const val chargeContentWidth = 354f
        const val headerTop = 59f
    }

    object Header {
        const val width = 370f
        const val height = 60f
        const val cornerRadius = 7f
        const val horizontalInset = 29f
        const val itemSpacing = 18f
        const val chevronSize = 25f
    }

    object Root {
        const val balanceTopInset = 18f
        const val menuTopInset = 19f
        const val menuSpacing = 10f
    }

    object Menu {
        const val height = 68f
        const val cornerRadius = 11f
        const val iconSize = 44f
        const val iconCornerRadius = 12f
        const val horizontalInset = 13f
        const val itemSpacing = 16f
    }

    object ThreadCharge {
        const val balanceHeight = 82f
        const val balanceCornerRadius = 20f
        const val balanceHorizontalInset = 18f
        const val balanceToAdSpacing = 20f
        const val adHeight = 136f
        const val adCornerRadius = 8f
        const val adToPackageSpacing = 21f
        const val packageHeight = 72f
        const val packageCornerRadius = 8f
        const val packageSpacing = 20f
    }
}

@Composable
fun MyPageScreen(
    profile: UserProfile?, body: BodyMeasurement?, threadBalance: Int, threadCharge: ThreadChargeState, busy: Boolean,
    error: String?, message: String?, onBack: () -> Unit, onHome: () -> Unit,
    onCloset: () -> Unit, onFitLab: () -> Unit, onRefresh: () -> Unit,
    onOpenThreadCharge: (Activity?) -> Unit, onShowRewardedAd: (Activity) -> Unit, onRetryRewardedAd: (Activity?) -> Unit,
    onRefreshAdPrivacy: (Activity?) -> Unit, onShowAdPrivacyOptions: (Activity?) -> Unit,
    onSaveProfile: (String) -> Unit, onSaveBody: (Double, Double) -> Unit,
    onLogout: () -> Unit, onDeleteAccount: () -> Unit, onClearMessage: () -> Unit,
) {
    var page by rememberSaveable { mutableStateOf(Page.Root) }
    val activity = LocalContext.current.findActivity()
    val contentScroll = rememberScrollState()
    val focusManager = LocalFocusManager.current
    val keyboard = LocalSoftwareKeyboardController.current
    LaunchedEffect(page) {
        focusManager.clearFocus(force = true)
        keyboard?.hide()
        contentScroll.scrollTo(0)
    }
    LaunchedEffect(threadCharge.status) {
        if (page == Page.ThreadCharge) contentScroll.scrollTo(0)
    }
    val leave = { if (page == Page.Root) onBack() else { page = parent(page); onClearMessage() } }
    BackHandler(enabled = !busy, onBack = leave)
    BoxWithConstraints(Modifier.fillMaxSize().testTag("mypage-screen")) {
        val scale = (maxWidth.value / MyPageDesign.designWidth).coerceIn(.82f, 1.25f)
        val contentWidth = if (page == Page.ThreadCharge) MyPageDesign.Shell.chargeContentWidth else MyPageDesign.Shell.standardContentWidth
        SharedAppBackground(scale)
        Column(
            Modifier.fillMaxSize().padding(top = (MyPageDesign.Shell.contentTop * scale).dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            MyPageHeader(page.title, scale, leave, Modifier.testTag("mypage-back"))
            key(page) {
                Column(
                    Modifier.width((contentWidth * scale).dp).weight(1f).verticalScroll(contentScroll)
                        .padding(top = (pageSpacing(page) * scale).dp, bottom = (MyPageDesign.Shell.contentBottom * scale).dp),
                    verticalArrangement = Arrangement.spacedBy((MyPageDesign.Shell.sectionSpacing * scale).dp),
                ) {
                    when (page) {
                        Page.Root -> RootPage(scale, threadBalance, onRefresh, {
                            page = Page.ThreadCharge
                            onOpenThreadCharge(activity)
                        }) { page = it }
                        Page.ThreadCharge -> ThreadChargePage(scale, threadBalance, threadCharge, onShowRewardedAd, { onRetryRewardedAd(activity) })
                        Page.Account -> AccountPage(scale, profile) { page = it }
                        Page.Profile -> ProfilePage(scale, profile, busy, onSaveProfile)
                        Page.Password -> InfoPage(scale, "비밀번호는 사용하지 않아요", "Coordit은 Google 또는 Apple 계정으로만 로그인합니다. 계정 접근 수단은 해당 제공자 설정에서 관리할 수 있어요.")
                        Page.Logout -> ConfirmPage(scale, "이 기기에서 로그아웃할까요?", "옷장과 핏 기록은 계정에 그대로 보관됩니다. 다시 로그인하면 이어서 사용할 수 있어요.", "로그아웃 확인", busy, false, onLogout)
                        Page.Delete -> DeletePage(scale, busy, onDeleteAccount)
                        Page.Body -> BodyPage(scale, profile, body) { page = Page.BodyEdit }
                        Page.BodyEdit -> BodyEditPage(scale, body, busy, onSaveBody)
                        Page.Notifications -> NotificationsPage(scale)
                        Page.Privacy -> PrivacyPage(scale, threadCharge, { onRefreshAdPrivacy(activity) }, { onShowAdPrivacyOptions(activity) }) { page = it }
                        Page.Policy -> DocumentPage(scale, policySections, "개인정보를 투명하게 다룹니다", "시행일 2026.07.07 · COORDIT 서비스 기준")
                        Page.Terms -> DocumentPage(scale, termsSections, "COORDIT 서비스 이용약관", "시행일 2026.07.07 · 앱 사용 전 주요 내용을 확인해 주세요.")
                        Page.Settings -> AppSettingsPage(scale)
                    }
                    if (error != null) StatusPanel(error, true, scale)
                    if (message != null) StatusPanel(message, false, scale)
                }
            }
        }
        CoorditHeader(scale, {}, Modifier.align(Alignment.TopCenter).padding(top = (MyPageDesign.Shell.headerTop * scale).dp))
        CoorditBottomNavigation(null, scale, { tab -> when (tab) {
            CoorditTab.Home -> onHome(); CoorditTab.FitLab -> onFitLab(); CoorditTab.Closet -> onCloset()
        } }, Modifier.align(Alignment.BottomCenter))
    }
}

private fun parent(page: Page) = when (page) {
    Page.Profile, Page.Password, Page.Logout, Page.Delete -> Page.Account
    Page.BodyEdit -> Page.Body
    Page.Policy, Page.Terms -> Page.Privacy
    else -> Page.Root
}

private fun pageSpacing(page: Page): Float = when (page) {
    Page.Root -> MyPageDesign.Root.menuSpacing
    Page.ThreadCharge, Page.Body -> 27f
    Page.Account, Page.Privacy, Page.Profile, Page.Password, Page.Logout, Page.Delete, Page.BodyEdit, Page.Policy, Page.Terms -> MyPageDesign.Shell.sectionSpacing
    Page.Notifications, Page.Settings -> 0f
}

@Composable
private fun MyPageHeader(title: String, scale: Float, onBack: () -> Unit, modifier: Modifier = Modifier) {
    val shape = RoundedCornerShape((7 * scale).dp)
    Pressable(
        onBack,
        modifier.width((MyPageDesign.Header.width * scale).dp).height((MyPageDesign.Header.height * scale).dp)
            .semantics { contentDescription = "$title 뒤로가기" },
        cornerRadius = MyPageDesign.Header.cornerRadius * scale,
    ) {
        Row(
            Modifier.fillMaxSize().background(AppColors.panel, shape).padding(horizontal = (MyPageDesign.Header.horizontalInset * scale).dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy((MyPageDesign.Header.itemSpacing * scale).dp),
        ) {
            Canvas(Modifier.size((MyPageDesign.Header.chevronSize * scale).dp)) {
                val stroke = 3f * scale * density
                drawLine(Color.Black, Offset(size.width * .62f, size.height * .12f), Offset(size.width * .27f, size.height * .5f), stroke, StrokeCap.Round)
                drawLine(Color.Black, Offset(size.width * .27f, size.height * .5f), Offset(size.width * .62f, size.height * .88f), stroke, StrokeCap.Round)
            }
            CoorditText(title, CoorditTypography.gmarketBold(22 * scale).copy(color = Color.Black, letterSpacing = (1.5f * scale).sp))
        }
    }
}

@Composable
private fun Chevron(scale: Float, color: Color = AppColors.muted) {
    Canvas(Modifier.size((18 * scale).dp)) {
        val stroke = 2f * scale * density
        drawLine(color, Offset(size.width * .35f, size.height * .15f), Offset(size.width * .67f, size.height * .5f), stroke, StrokeCap.Round)
        drawLine(color, Offset(size.width * .67f, size.height * .5f), Offset(size.width * .35f, size.height * .85f), stroke, StrokeCap.Round)
    }
}

@Composable private fun RootPage(scale: Float, balance: Int, refresh: () -> Unit, charge: () -> Unit, open: (Page) -> Unit) {
    LaunchedEffect(Unit) { refresh() }
    Column(verticalArrangement = Arrangement.spacedBy((MyPageDesign.Root.menuSpacing * scale).dp)) {
        SettingsCard(scale, Modifier.padding(top = (MyPageDesign.Root.balanceTopInset * scale).dp).testTag("mypage-yarn-balance-card")) {
            Row(
                Modifier.fillMaxWidth().padding(horizontal = (13 * scale).dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy((12 * scale).dp),
            ) {
                Image(painterResource(R.drawable.coordit_yarn), null, Modifier.size((48 * scale).dp))
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy((4 * scale).dp)) {
                    CoorditText("보유 실타래", CoorditTypography.gmarketMedium(10 * scale).copy(color = AppColors.muted))
                    CoorditText("${balance} 실타래", CoorditTypography.gmarketBold(20 * scale))
                }
                Pressable(charge, Modifier.width((62 * scale).dp).height((44 * scale).dp).testTag("thread-charge"), cornerRadius = 7 * scale) {
                    Box(Modifier.fillMaxSize().background(AppColors.ink, RoundedCornerShape((7 * scale).dp)), contentAlignment = Alignment.Center) {
                        CoorditText("충전", CoorditTypography.gmarketBold(12 * scale).copy(color = Color.White))
                    }
                }
            }
        }
        Column(Modifier.padding(top = (MyPageDesign.Root.menuTopInset * scale).dp), verticalArrangement = Arrangement.spacedBy((MyPageDesign.Root.menuSpacing * scale).dp)) {
            listOf(
                Menu(Page.Account, "계정", "프로필, 연결 계정, 로그아웃", R.drawable.coordit_mypage_account),
                Menu(Page.Body, "내 신체 정보", "키, 몸무게, 성별, 생일", R.drawable.coordit_mypage_body),
                Menu(Page.Notifications, "알림", "구매 후 피드백, 재확인, 리포트", R.drawable.coordit_mypage_notifications),
                Menu(Page.Privacy, "개인정보/보안", "정책, 약관, 데이터 동의", R.drawable.coordit_mypage_privacy),
                Menu(Page.Settings, "앱 설정", "알림, 버전, 문의", R.drawable.coordit_mypage_settings),
            ).forEach { menu -> MyPageMenuRow(menu, scale) { open(menu.page) } }
        }
    }
}

@Composable
private fun ThreadChargePage(
    scale: Float,
    balance: Int,
    charge: ThreadChargeState,
    showRewardedAd: (Activity) -> Unit,
    retryRewardedAd: () -> Unit,
) {
    val activity = LocalContext.current.findActivity()
    Column(Modifier.fillMaxWidth()) {
        Row(
            Modifier.fillMaxWidth().height((MyPageDesign.ThreadCharge.balanceHeight * scale).dp).background(AppColors.panel, RoundedCornerShape((MyPageDesign.ThreadCharge.balanceCornerRadius * scale).dp))
                .padding(horizontal = (MyPageDesign.ThreadCharge.balanceHorizontalInset * scale).dp).testTag("coordit-thread-charge-balance"),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy((12 * scale).dp),
        ) {
            Image(painterResource(R.drawable.coordit_yarn), null, Modifier.size((50 * scale).dp))
            Column(verticalArrangement = Arrangement.spacedBy((4 * scale).dp)) {
                CoorditText("보유 실타래", CoorditTypography.gmarketBold(12 * scale).copy(color = AppColors.muted))
                CoorditText("${balance} 실타래", CoorditTypography.gmarketBold(29 * scale))
            }
        }
        Spacer(Modifier.height((MyPageDesign.ThreadCharge.balanceToAdSpacing * scale).dp))

        if (!charge.isRewardedAdVisible && !charge.message.isNullOrBlank()) {
            ReadinessStatus(charge.message, charge.canRetry, retryRewardedAd, scale)
            Spacer(Modifier.height((4 * scale).dp))
        }

        if (charge.isRewardedAdVisible) {
            val shape = RoundedCornerShape((MyPageDesign.ThreadCharge.adCornerRadius * scale).dp)
            Pressable(
                onClick = { activity?.let(showRewardedAd) },
                enabled = charge.canWatchAd && activity != null,
                cornerRadius = MyPageDesign.ThreadCharge.adCornerRadius * scale,
                modifier = Modifier.fillMaxWidth()
                    .coorditShadow(Color.Black.copy(alpha = .18f), (18 * scale).dp, shape, (9 * scale).dp)
                    .testTag("thread-charge-rewarded-ad"),
            ) {
                Row(
                    Modifier.fillMaxWidth().height((MyPageDesign.ThreadCharge.adHeight * scale).dp)
                        .background(Brush.verticalGradient(listOf(AppColors.chargeGradientTop, AppColors.ink, AppColors.chargeGradientEnd)), shape)
                        .padding(horizontal = (15 * scale).dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy((14 * scale).dp),
                ) {
                    Box(Modifier.size((44 * scale).dp).background(Color.White.copy(alpha = .14f), RoundedCornerShape((12 * scale).dp)), contentAlignment = Alignment.Center) {
                        Image(painterResource(R.drawable.coordit_recharge_play), null, Modifier.size((24 * scale).dp))
                    }
                    CoorditText("광고 보고 실타래 충전하기", CoorditTypography.gmarketBold(18 * scale).copy(color = Color.White), Modifier.weight(1f))
                    Chevron(scale, Color.White)
                }
            }
            Spacer(Modifier.height((MyPageDesign.ThreadCharge.adToPackageSpacing * scale).dp))
            charge.message?.let { status ->
                CoorditText(status, CoorditTypography.gmarketMedium(11 * scale).copy(color = AppColors.ink.copy(alpha = .72f), textAlign = TextAlign.Center),
                    Modifier.fillMaxWidth().testTag("thread-charge-status"))
                Spacer(Modifier.height((10 * scale).dp))
            }
            if (charge.canRetry) {
                RetryButton(retryRewardedAd, scale)
                Spacer(Modifier.height((10 * scale).dp))
            }
        } else if (charge.canRetry && charge.message.isNullOrBlank()) {
            RetryButton(retryRewardedAd, scale)
            Spacer(Modifier.height((10 * scale).dp))
        }

        CoorditText("패키지 구매는 출시 준비 중이에요.", CoorditTypography.gmarketMedium(10 * scale).copy(color = AppColors.purchaseStatus, textAlign = TextAlign.Center),
            Modifier.fillMaxWidth().testTag("thread-charge-purchase-notice"))
        Spacer(Modifier.height((10 * scale).dp))
        Column(verticalArrangement = Arrangement.spacedBy((MyPageDesign.ThreadCharge.packageSpacing * scale).dp)) {
            listOf("5 실타래" to "1,500원", "10 실타래" to "2,500원", "20 실타래" to "4,000원").forEachIndexed { index, (amount, price) ->
                ThreadPackageRow(amount, price, highlighted = index == 1, scale = scale, tag = "thread-charge-pack-${index + 1}")
            }
        }
    }
}

@Composable
private fun ReadinessStatus(message: String, canRetry: Boolean, retry: () -> Unit, scale: Float) {
    Row(
        Modifier.fillMaxWidth().testTag("thread-charge-status"),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy((8 * scale).dp),
    ) {
        CoorditText(message, CoorditTypography.gmarketMedium(11 * scale).copy(color = AppColors.ink.copy(alpha = .72f)), Modifier.weight(1f))
        if (canRetry) RetryButton(retry, scale)
    }
}

@Composable
private fun RetryButton(retry: () -> Unit, scale: Float) {
    Pressable(retry, Modifier.width((64 * scale).dp).height((44 * scale).dp).testTag("thread-charge-retry"), cornerRadius = 7 * scale) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            CoorditText("다시 시도", CoorditTypography.gmarketBold(11 * scale).copy(color = AppColors.ink))
        }
    }
}

@Composable
private fun ThreadPackageRow(amount: String, price: String, highlighted: Boolean, scale: Float, tag: String) {
    val shape = RoundedCornerShape((MyPageDesign.ThreadCharge.packageCornerRadius * scale).dp)
    Pressable({}, enabled = false, cornerRadius = MyPageDesign.ThreadCharge.packageCornerRadius * scale, modifier = Modifier.fillMaxWidth().testTag(tag)) {
        Row(
            Modifier.fillMaxWidth().height((MyPageDesign.ThreadCharge.packageHeight * scale).dp).background(AppColors.panel, shape)
                .border(if (highlighted) (2 * scale).dp else 1.dp, if (highlighted) AppColors.warmLine else AppColors.line, shape)
                .padding(horizontal = (16 * scale).dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy((12 * scale).dp),
        ) {
            Image(painterResource(R.drawable.coordit_yarn), null, Modifier.size((54 * scale).dp))
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy((3 * scale).dp)) {
                CoorditText(amount, CoorditTypography.gmarketBold(16 * scale))
                CoorditText("실타래 충전", CoorditTypography.gmarketMedium(9 * scale).copy(color = AppColors.muted))
            }
            Box(Modifier.height((31 * scale).dp).background(AppColors.ink, CircleShape).padding(horizontal = (12 * scale).dp), contentAlignment = Alignment.Center) {
                CoorditText(price, CoorditTypography.gmarketBold(13 * scale).copy(color = Color.White))
            }
        }
    }
}

private tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}

private data class Menu(val page: Page, val title: String, val subtitle: String, val icon: Int)

@Composable
private fun MyPageMenuRow(menu: Menu, scale: Float, open: () -> Unit) {
    val shape = RoundedCornerShape((MyPageDesign.Menu.cornerRadius * scale).dp)
    Pressable(open, Modifier.fillMaxWidth().coorditShadow(Color.Black.copy(alpha = .05f), (10 * scale).dp, shape, (4 * scale).dp)
        .testTag("mypage-${menu.page.name.lowercase()}"), cornerRadius = MyPageDesign.Menu.cornerRadius * scale) {
        Row(
            Modifier.fillMaxWidth().height((MyPageDesign.Menu.height * scale).dp).background(AppColors.panel, shape)
                .padding(horizontal = (MyPageDesign.Menu.horizontalInset * scale).dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy((MyPageDesign.Menu.itemSpacing * scale).dp),
        ) {
            Box(Modifier.size((MyPageDesign.Menu.iconSize * scale).dp).background(AppColors.ink, RoundedCornerShape((MyPageDesign.Menu.iconCornerRadius * scale).dp)), contentAlignment = Alignment.Center) {
                Image(painterResource(menu.icon), null, Modifier.size((24 * scale).dp))
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy((4 * scale).dp)) {
                CoorditText(menu.title, CoorditTypography.gmarketBold(16 * scale))
                CoorditText(menu.subtitle, CoorditTypography.gmarketMedium(9 * scale).copy(color = AppColors.muted))
            }
            Chevron(scale)
        }
    }
}

@Composable
private fun AccountPage(scale: Float, profile: UserProfile?, open: (Page) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy((18 * scale).dp)) {
        SettingsCard(scale) {
            Column(
                Modifier.padding(horizontal = (13 * scale).dp),
                verticalArrangement = Arrangement.spacedBy((13 * scale).dp),
            ) {
                Column(verticalArrangement = Arrangement.spacedBy((4 * scale).dp)) {
                    CoorditText(profile?.displayName ?: "코딧 사용자", CoorditTypography.gmarketBold(14 * scale).copy(color = AppColors.ink))
                    CoorditText(profile?.email ?: "로그인 계정을 확인하고 있어요.", CoorditTypography.gmarketMedium(10 * scale).copy(color = AppColors.muted))
                }
                CoorditButton("이 기기에서 로그아웃", { open(Page.Logout) }, height = 48 * scale, fontSize = 13 * scale, cornerRadius = MyPageDesign.Header.cornerRadius * scale,
                    modifier = Modifier.testTag("mypage-backend-local-logout"))
            }
        }
        SettingsCard(scale) {
            SettingsActionRow("프로필 수정", "이름, 사진, 기본 소개", "open-profile", scale) { open(Page.Profile) }
            SettingsDivider(scale)
            SettingsDetailRow("연결 계정", scale) { SettingsValuePill(profile?.email ?: "계정 없음", scale) }
            SettingsDivider(scale)
            SettingsActionRow("회원 탈퇴", "계정 및 데이터 삭제", "open-delete", scale, danger = true) { open(Page.Delete) }
        }
    }
}

@Composable
private fun ProfilePage(scale: Float, profile: UserProfile?, busy: Boolean, save: (String) -> Unit) {
    var name by remember(profile?.displayName) { mutableStateOf(profile?.displayName.orEmpty()) }
    var bio by rememberSaveable { mutableStateOf("나에게 꼭 맞는 핏을 찾고 있어요.") }
    var alternateAvatar by rememberSaveable { mutableStateOf(false) }
    Column(verticalArrangement = Arrangement.spacedBy((18 * scale).dp)) {
        SettingsCard(scale) {
            Column(
                Modifier.padding(horizontal = (13 * scale).dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy((15 * scale).dp),
            ) {
                Box(
                    Modifier.size((76 * scale).dp).background(if (alternateAvatar) AppColors.settingsValue else AppColors.settingsField, CircleShape),
                    contentAlignment = Alignment.Center,
                ) {
                    Image(
                    painter = painterResource(R.drawable.figma_top_my),
                    contentDescription = null,
                    modifier = Modifier.size((34 * scale).dp),
                    colorFilter = ColorFilter.tint(AppColors.ink),
                )
                }
                Pressable({ alternateAvatar = !alternateAvatar }, Modifier.height((30 * scale).dp), cornerRadius = 7 * scale) {
                    CoorditText("기본 이미지 바꾸기", CoorditTypography.gmarketBold(10 * scale).copy(color = AppColors.ink))
                }
                SettingsInput("이름", "이름을 입력하세요", name, { if (it.length <= 30) name = it }, "mypage-profile-name", scale)
                SettingsInput("기본 소개", "나를 소개하는 한 줄을 적어주세요", bio, { if (it.length <= 120) bio = it }, "mypage-profile-bio", scale, multiline = true)
            }
        }
        CoorditButton(
            if (busy) "저장 중..." else "프로필 저장",
            { save(name.trim()) },
            enabled = !busy && name.trim().isNotEmpty(),
            height = 48 * scale,
            fontSize = 13 * scale,
            cornerRadius = MyPageDesign.Header.cornerRadius * scale,
            modifier = Modifier.testTag("profile-save"),
        )
    }
}

@Composable
private fun BodyPage(scale: Float, profile: UserProfile?, body: BodyMeasurement?, edit: () -> Unit) {
    SettingsCard(scale) {
        ValueRow("키", body?.heightCm?.let { "${format(it)} cm" } ?: "미등록", scale); SettingsDivider(scale)
        ValueRow("몸무게", body?.weightKg?.let { "${format(it)} kg" } ?: "미등록", scale); SettingsDivider(scale)
        ValueRow("성별", when (profile?.gender?.lowercase()) { "male" -> "남성"; "female" -> "여성"; "prefer_not_to_say" -> "응답하지 않음"; else -> "미등록" }, scale); SettingsDivider(scale)
        ValueRow("생일", profile?.birthDate ?: profile?.birthYear?.toString() ?: "미등록", scale); SettingsDivider(scale)
        SettingsActionRow("신체 정보 수정", "키와 몸무게 수정", "body-edit", scale, onClick = edit)
    }
}

@Composable
private fun BodyEditPage(scale: Float, body: BodyMeasurement?, busy: Boolean, save: (Double, Double) -> Unit) {
    var height by remember(body?.heightCm) { mutableStateOf(body?.heightCm?.let(::format).orEmpty()) }
    var weight by remember(body?.weightKg) { mutableStateOf(body?.weightKg?.let(::format).orEmpty()) }
    val h = height.toDoubleOrNull(); val w = weight.toDoubleOrNull(); val valid = h != null && w != null && h in 80.0..250.0 && w in 20.0..300.0
    Column(verticalArrangement = Arrangement.spacedBy((18 * scale).dp)) {
        SettingsCard(scale) {
            Column(Modifier.padding(horizontal = (13 * scale).dp), verticalArrangement = Arrangement.spacedBy((13 * scale).dp)) {
                SettingsInput("키", "키를 입력하세요", height, { height = cleanNumber(it) }, "mypage-measurement-height", scale, keyboardType = KeyboardType.Decimal)
                SettingsInput("몸무게", "몸무게를 입력하세요", weight, { weight = cleanNumber(it) }, "mypage-measurement-weight", scale, keyboardType = KeyboardType.Decimal)
            }
        }
        CoorditButton(
            if (busy) "저장 중..." else "키와 몸무게 저장",
            { save(h!!, w!!) },
            enabled = valid && !busy,
            height = 48 * scale,
            fontSize = 13 * scale,
            cornerRadius = MyPageDesign.Header.cornerRadius * scale,
            modifier = Modifier.testTag("body-save"),
        )
    }
}

@Composable
private fun NotificationsPage(scale: Float) {
    val context = LocalContext.current
    var enabled by remember { mutableStateOf(NotificationManagerCompat.from(context).areNotificationsEnabled()) }
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) enabled = NotificationManagerCompat.from(context).areNotificationsEnabled()
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }
    var marketing by rememberPreference("marketing_notifications", false)
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        enabled = granted
        marketing = granted
    }
    val status = when {
        !enabled -> "기기 설정에서 COORDIT 알림을 허용해 주세요."
        marketing -> "마케팅 알림이 켜져 있어요."
        else -> "기기 알림은 허용되어 있지만 마케팅 알림은 꺼져 있어요."
    }
    Column(verticalArrangement = Arrangement.spacedBy((18 * scale).dp)) {
        SettingsCard(scale) {
            SettingsDetailRow("마케팅 알림", scale, subtitle = "혜택과 이벤트") {
                SettingsToggle(marketing && enabled, { requested ->
                    if (!requested) marketing = false
                    else if (!enabled && Build.VERSION.SDK_INT >= 33) launcher.launch(Manifest.permission.POST_NOTIFICATIONS)
                    else { marketing = true; context.openAppSettings() }
                }, "마케팅 알림", scale)
            }
        }
        SettingsStatusBanner(status, "mypage-marketing-notifications-status", scale, warning = !enabled)
        SettingsCard(scale) {
            SettingsActionRow("앱 알림 설정", "시스템 알림 허용 상태 변경", "notification-settings", scale) {
                if (!enabled && Build.VERSION.SDK_INT >= 33) launcher.launch(Manifest.permission.POST_NOTIFICATIONS)
                else context.openAppSettings()
            }
        }
    }
}

@Composable
private fun PrivacyPage(
    scale: Float,
    charge: ThreadChargeState,
    refreshAdPrivacy: () -> Unit,
    showAdPrivacyOptions: () -> Unit,
    open: (Page) -> Unit,
) {
    var feedback by rememberPreference("feedback_personalization", true)
    var ai by rememberPreference("ai_data_use", false)
    LaunchedEffect(Unit) { refreshAdPrivacy() }
    SettingsCard(scale) {
        SettingsActionRow("개인정보 처리방침", "서비스 데이터 처리 기준", "open-policy", scale) { open(Page.Policy) }
        SettingsDivider(scale)
        SettingsActionRow("서비스 이용약관", "2026.06.30 기준", "open-terms", scale) { open(Page.Terms) }
        SettingsDivider(scale)
        SettingsActionRow("광고 개인정보 설정", charge.privacyStatusText, "ad-privacy-options", scale, statusTag = "ad-privacy-status", onClick = showAdPrivacyOptions)
        SettingsDivider(scale)
        SettingsDetailRow("데이터 수집 동의", scale) { SettingsValuePill("필수 동의 완료", scale) }
        SettingsDivider(scale)
        SettingsDetailRow("피드백 데이터 개인화 사용 동의", scale, subtitle = "추천 개선에 사용") { SettingsToggle(feedback, { feedback = it }, "피드백 데이터 개인화 사용 동의", scale) }
        SettingsDivider(scale)
        SettingsDetailRow("AI/ML 추천 개선 데이터 사용 동의", scale, subtitle = "비식별 학습 반영") { SettingsToggle(ai, { ai = it }, "AI/ML 추천 개선 데이터 사용 동의", scale) }
    }
}

@Composable
private fun AppSettingsPage(scale: Float) {
    val context = LocalContext.current
    SettingsCard(scale) {
        SettingsDetailRow("앱 버전", scale) { SettingsValuePill("v${BuildConfig.VERSION_NAME}", scale) }
        SettingsDivider(scale)
        SettingsActionRow("문의하기", "hyu.coordit@gmail.com", "support-email", scale) { context.sendSupportEmail() }
    }
}

@Composable
private fun SettingsActionRow(
    title: String,
    subtitle: String?,
    tag: String,
    scale: Float,
    danger: Boolean = false,
    statusTag: String? = null,
    onClick: () -> Unit,
) {
    Pressable(onClick, Modifier.fillMaxWidth().height((55 * scale).dp).testTag(tag), cornerRadius = 7 * scale) {
        Row(
            Modifier.fillMaxSize().padding(horizontal = (13 * scale).dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy((12 * scale).dp),
        ) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy((3 * scale).dp)) {
                CoorditText(title, CoorditTypography.gmarketBold(12 * scale).copy(color = if (danger) AppColors.danger else Color.Black))
                subtitle?.let { CoorditText(it, CoorditTypography.gmarketMedium(9 * scale).copy(color = AppColors.muted), Modifier.then(if (statusTag == null) Modifier else Modifier.testTag(statusTag))) }
            }
            Chevron(scale, if (danger) AppColors.danger else AppColors.muted)
        }
    }
}

@Composable
private fun SettingsInput(
    title: String,
    placeholder: String,
    value: String,
    onChange: (String) -> Unit,
    tag: String,
    scale: Float,
    multiline: Boolean = false,
    keyboardType: KeyboardType = KeyboardType.Text,
) {
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy((7 * scale).dp)) {
        CoorditText(title, CoorditTypography.gmarketBold(11 * scale).copy(color = AppColors.ink))
        androidx.compose.foundation.text.BasicTextField(
            value = value,
            onValueChange = onChange,
            modifier = Modifier.fillMaxWidth().heightIn(min = ((if (multiline) 92 else 48) * scale).dp)
                .background(AppColors.settingsField, RoundedCornerShape((7 * scale).dp))
                .border(1.dp, AppColors.line, RoundedCornerShape((7 * scale).dp))
                .padding(horizontal = (13 * scale).dp, vertical = (12 * scale).dp)
                .testTag(tag).semantics { contentDescription = title },
            textStyle = CoorditTypography.gmarketMedium(12 * scale).copy(color = Color.Black),
            keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
            singleLine = !multiline,
            maxLines = if (multiline) 5 else 1,
            decorationBox = { inner ->
                Box(contentAlignment = Alignment.TopStart) {
                    if (value.isEmpty()) CoorditText(placeholder, CoorditTypography.gmarketMedium(12 * scale).copy(color = AppColors.muted))
                    inner()
                }
            },
        )
    }
}

@Composable
private fun SettingsStatusBanner(text: String, tag: String, scale: Float, warning: Boolean = false) {
    Row(
        Modifier.fillMaxWidth().heightIn(min = (42 * scale).dp)
            .background(if (warning) AppColors.danger.copy(alpha = .09f) else AppColors.green.copy(alpha = .10f), RoundedCornerShape((7 * scale).dp))
            .padding(horizontal = (13 * scale).dp).testTag(tag),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy((9 * scale).dp),
    ) {
        CoorditText(if (warning) "!" else "✓", CoorditTypography.gmarketBold(15 * scale).copy(color = if (warning) AppColors.danger else AppColors.ink))
        CoorditText(text, CoorditTypography.gmarketMedium(10 * scale).copy(color = if (warning) AppColors.danger else AppColors.ink), Modifier.weight(1f))
    }
}

@Composable
private fun DeletePage(scale: Float, busy: Boolean, delete: () -> Unit) {
    var accepted by rememberSaveable { mutableStateOf(false) }
    Column(verticalArrangement = Arrangement.spacedBy((18 * scale).dp)) {
        InfoPanel(scale, "!", "계정과 데이터를 삭제합니다", "탈퇴하면 저장한 신체 정보, 옷장, 핏 리포트를 복구할 수 없습니다.", danger = true)
        Pressable({ accepted = !accepted }, Modifier.fillMaxWidth().testTag("delete-ack"), cornerRadius = 7 * scale) {
            Row(
                Modifier.fillMaxWidth().heightIn(min = (48 * scale).dp).background(AppColors.panel, RoundedCornerShape((7 * scale).dp))
                    .padding((13 * scale).dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy((10 * scale).dp),
            ) {
                CoorditText(if (accepted) "✓" else "□", CoorditTypography.gmarketBold(19 * scale).copy(color = if (accepted) AppColors.danger else AppColors.muted))
                CoorditText("삭제되는 데이터와 복구 불가 안내를 확인했습니다.", CoorditTypography.gmarketMedium(10 * scale).copy(color = Color.Black), Modifier.weight(1f))
            }
        }
        Pressable(delete, Modifier.fillMaxWidth().height((48 * scale).dp).testTag("delete-account"), enabled = accepted && !busy, cornerRadius = 7 * scale) {
            Box(Modifier.fillMaxSize().background(AppColors.danger, RoundedCornerShape((7 * scale).dp)), contentAlignment = Alignment.Center) {
                CoorditText(if (busy) "삭제 중..." else "회원 탈퇴 확인", CoorditTypography.gmarketBold(13 * scale).copy(color = Color.White))
            }
        }
    }
}

@Composable
private fun ConfirmPage(scale: Float, title: String, body: String, action: String, busy: Boolean, danger: Boolean, confirm: () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy((18 * scale).dp)) {
        InfoPanel(scale, "•", title, body, danger = danger)
        CoorditButton(if (busy) "처리 중..." else action, confirm, enabled = !busy, secondary = false,
            height = 48 * scale, fontSize = 13 * scale, cornerRadius = MyPageDesign.Header.cornerRadius * scale, modifier = Modifier.testTag("confirm-action"))
    }
}

@Composable
private fun InfoPage(scale: Float, title: String, body: String) = InfoPanel(scale, "i", title, body)

@Composable
private fun InfoPanel(scale: Float, symbol: String, title: String, body: String, danger: Boolean = false) {
    Column(
        Modifier.fillMaxWidth().background(AppColors.panel, RoundedCornerShape((7 * scale).dp))
            .border(1.dp, if (danger) AppColors.danger.copy(alpha = .28f) else AppColors.line, RoundedCornerShape((7 * scale).dp))
            .padding((22 * scale).dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy((13 * scale).dp),
    ) {
        Box(Modifier.size((56 * scale).dp).background(AppColors.settingsField, CircleShape), contentAlignment = Alignment.Center) {
            CoorditText(symbol, CoorditTypography.gmarketBold(28 * scale).copy(color = if (danger) AppColors.danger else AppColors.ink))
        }
        CoorditText(title, CoorditTypography.gmarketBold(16 * scale))
        CoorditText(body, CoorditTypography.gmarketMedium(11 * scale).copy(color = AppColors.muted, textAlign = TextAlign.Center, lineHeight = (15 * scale).sp))
    }
}

private data class DocumentSection(val title: String, val body: String)

@Composable
private fun DocumentPage(scale: Float, sections: List<DocumentSection>, title: String, detail: String) {
    Column(verticalArrangement = Arrangement.spacedBy((18 * scale).dp)) {
        InfoPanel(scale, "i", title, detail)
        SettingsCard(scale) {
            sections.forEachIndexed { index, section ->
                Column(Modifier.padding(horizontal = (14 * scale).dp, vertical = (13 * scale).dp), verticalArrangement = Arrangement.spacedBy((8 * scale).dp)) {
                    CoorditText(section.title, CoorditTypography.gmarketBold(12 * scale).copy(color = AppColors.ink))
                    CoorditText(section.body, CoorditTypography.gmarketMedium(10 * scale).copy(color = Color.Black.copy(alpha = .76f), lineHeight = (14 * scale).sp))
                }
                if (index < sections.lastIndex) SettingsDivider(scale)
            }
        }
    }
}

@Composable private fun ValueRow(title: String, value: String, scale: Float) { SettingsDetailRow(title, scale) { SettingsValuePill(value, scale) } }
@Composable private fun StatusPanel(text: String, error: Boolean, scale: Float) { Box(Modifier.fillMaxWidth().background(if (error) AppColors.danger.copy(alpha = .12f) else AppColors.settingsValue, RoundedCornerShape((7 * scale).dp)).padding((12 * scale).dp)) { CoorditText(text, CoorditTypography.gmarketMedium(10 * scale).copy(color = if (error) AppColors.danger else AppColors.ink)) } }

@Composable private fun rememberPreference(key: String, default: Boolean): MutableState<Boolean> {
    val context = LocalContext.current
    val preferences = remember { context.getSharedPreferences("coordit-settings", Context.MODE_PRIVATE) }
    val state = remember { mutableStateOf(preferences.getBoolean(key, default)) }
    return object : MutableState<Boolean> by state { override var value: Boolean get() = state.value; set(value) { state.value = value; preferences.edit().putBoolean(key, value).apply() } }
}
private fun Context.openAppSettings() { startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)) }
private fun Context.sendSupportEmail() {
    val intent = Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:hyu.coordit@gmail.com?subject=Coordit%20Android%20문의"))
    if (intent.resolveActivity(packageManager) != null) startActivity(intent)
    else Toast.makeText(this, "사용할 수 있는 이메일 앱이 없어요.", Toast.LENGTH_SHORT).show()
}
private fun cleanNumber(value: String) = value.filter { it.isDigit() || it == '.' }.let { filtered -> if (filtered.count { it == '.' } <= 1) filtered.take(6) else filtered.dropLast(1) }
private fun format(value: Double) = DecimalFormat("0.#").format(value)

private val policySections = listOf(
    DocumentSection("1. 수집하는 정보", "서비스는 계정 정보, 사용자가 입력한 신체 정보, 옷장 기록과 핏 분석 결과를 수집합니다. 선택 동의 항목은 설정에서 언제든 변경할 수 있습니다."),
    DocumentSection("2. 이용 목적", "수집한 정보는 사이즈 추천, 옷장 관리, 핏 리포트 제공과 서비스 품질 개선에 사용합니다. 동의한 목적 밖으로 사용하지 않습니다."),
    DocumentSection("3. 보관과 삭제", "정보는 서비스 이용 기간 동안 보관하며 회원 탈퇴 또는 삭제 요청 시 관련 법령에서 정한 기간을 제외하고 안전하게 삭제합니다."),
    DocumentSection("4. 이용자의 권리", "사용자는 자신의 정보를 열람, 수정, 삭제하거나 처리 정지를 요청할 수 있습니다. 문의 이메일을 통해 개인정보 관련 요청을 접수할 수 있습니다."),
    DocumentSection("5. 비개인화 광고", "보상형 광고는 Google Mobile Ads SDK를 통해 비개인화 방식으로 제공됩니다. 광고 제공 과정에서 IP 주소를 바탕으로 한 대략적 위치, 기기 식별자, 광고 데이터, 앱 상호작용, 진단 및 성능 정보가 처리될 수 있습니다. 맞춤형 광고나 앱 추적 권한은 사용하지 않으며, 광고 개인정보 설정은 개인정보/보안 화면에서 확인할 수 있습니다."),
)
private val termsSections = listOf(
    DocumentSection("1. 서비스의 목적", "COORDIT은 사용자가 기록한 정보와 옷 데이터를 바탕으로 개인화된 핏 분석과 옷장 관리 기능을 제공합니다."),
    DocumentSection("2. 계정과 책임", "사용자는 정확한 정보를 제공하고 계정 접근 수단을 안전하게 관리해야 합니다. 다른 사람의 정보를 허가 없이 등록할 수 없습니다."),
    DocumentSection("3. 추천 정보", "핏 점수와 사이즈 추천은 선택을 돕기 위한 참고 정보입니다. 브랜드와 소재, 착용 선호에 따라 실제 결과가 달라질 수 있습니다."),
    DocumentSection("4. 이용 제한과 변경", "서비스 안정성과 사용자 보호를 위해 부정 사용을 제한할 수 있으며, 중요한 약관 변경은 앱 안에서 사전에 안내합니다."),
)
