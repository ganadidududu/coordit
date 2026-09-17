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
import androidx.compose.ui.graphics.Color
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
    Delete("회원탈퇴"), Body("내 신체 정보"), BodyEdit("신체 정보 수정"), Notifications("알림"),
    Privacy("개인정보/보안"), Policy("개인정보 처리방침"), Terms("서비스 이용약관"), Settings("앱 설정"),
    ThreadCharge("실타래 충전")
}

@Composable
fun MyPageScreen(
    profile: UserProfile?, body: BodyMeasurement?, threadBalance: Int, threadCharge: ThreadChargeState, busy: Boolean,
    error: String?, message: String?, onBack: () -> Unit, onHome: () -> Unit,
    onCloset: () -> Unit, onFitLab: () -> Unit, onRefresh: () -> Unit,
    onOpenThreadCharge: () -> Unit, onShowRewardedAd: (Activity) -> Unit, onRetryRewardedAd: () -> Unit,
    onSaveProfile: (String) -> Unit, onSaveBody: (Double, Double) -> Unit,
    onLogout: () -> Unit, onDeleteAccount: () -> Unit, onClearMessage: () -> Unit,
) {
    var page by rememberSaveable { mutableStateOf(Page.Root) }
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
        val scale = (maxWidth.value / 402f).coerceIn(.82f, 1.25f)
        SharedAppBackground(scale)
        Column(Modifier.fillMaxSize().padding(top = (78 * scale).dp, bottom = (84 * scale).dp), horizontalAlignment = Alignment.CenterHorizontally) {
            BackTitleCard(page.title, scale, leave, Modifier.testTag("mypage-back"))
            key(page) { Column(Modifier.widthIn(max = (372 * scale).dp).fillMaxWidth().weight(1f).verticalScroll(contentScroll)
                .padding(horizontal = (1 * scale).dp, vertical = (13 * scale).dp), verticalArrangement = Arrangement.spacedBy((12 * scale).dp)) {
                when (page) {
                    Page.Root -> RootPage(scale, profile, threadBalance, onRefresh, {
                        page = Page.ThreadCharge
                        onOpenThreadCharge()
                    }) { page = it }
                    Page.ThreadCharge -> ThreadChargePage(scale, threadBalance, threadCharge, onShowRewardedAd, onRetryRewardedAd)
                    Page.Account -> AccountPage(scale, profile) { page = it }
                    Page.Profile -> ProfilePage(scale, profile, busy, onSaveProfile)
                    Page.Password -> InfoPage(scale, "소셜 로그인 계정", "Google 계정으로 로그인하고 있어 별도의 비밀번호를 사용하지 않아요. 비밀번호는 Google 계정에서 변경할 수 있어요.")
                    Page.Logout -> ConfirmPage(scale, "로그아웃할까요?", "이 기기의 로그인 정보가 삭제됩니다. 저장한 분석 결과는 계정에 그대로 남아 있어요.", "로그아웃", busy, false, onLogout)
                    Page.Delete -> DeletePage(scale, busy, onDeleteAccount)
                    Page.Body -> BodyPage(scale, profile, body) { page = Page.BodyEdit }
                    Page.BodyEdit -> BodyEditPage(scale, body, busy, onSaveBody)
                    Page.Notifications -> NotificationsPage(scale)
                    Page.Privacy -> PrivacyPage(scale) { page = it }
                    Page.Policy -> DocumentPage(scale, policyText)
                    Page.Terms -> DocumentPage(scale, termsText)
                    Page.Settings -> AppSettingsPage(scale)
                }
                if (error != null) StatusPanel(error, true, scale)
                if (message != null) StatusPanel(message, false, scale)
                Spacer(Modifier.height((18 * scale).dp))
            } }
        }
        CoorditHeader(scale, {}, Modifier.align(Alignment.TopCenter).padding(top = (25 * scale).dp))
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

@Composable private fun RootPage(scale: Float, profile: UserProfile?, balance: Int, refresh: () -> Unit, charge: () -> Unit, open: (Page) -> Unit) {
    LaunchedEffect(Unit) { refresh() }
    SettingsCard(scale) {
        Row(Modifier.fillMaxWidth().padding((16 * scale).dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size((62 * scale).dp).background(AppColors.settingsValue, CircleShape), contentAlignment = Alignment.Center) {
                Image(painterResource(R.drawable.coordit_yarn), null, Modifier.size((48 * scale).dp))
            }
            Spacer(Modifier.width((14 * scale).dp))
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy((5 * scale).dp)) {
                CoorditText(profile?.displayName ?: "내 계정", CoorditTypography.gmarketBold(16 * scale))
                CoorditText("보유 실타래", CoorditTypography.gmarketMedium(10 * scale).copy(color = AppColors.muted))
                CoorditText("${balance} 실타래", CoorditTypography.gmarketBold(13 * scale))
            }
            SmallButton("충전", charge, scale, "thread-charge")
        }
    }
    MenuCard(scale, listOf(
        Menu(Page.Account, "계정", "프로필, 연결 계정, 로그아웃", R.drawable.coordit_mypage_account),
        Menu(Page.Body, "내 신체 정보", "키, 몸무게, 성별, 생일", R.drawable.coordit_mypage_body),
        Menu(Page.Notifications, "알림", "구매 후 피드백, 재확인, 리포트", R.drawable.coordit_mypage_notifications),
        Menu(Page.Privacy, "개인정보/보안", "정책, 약관, 데이터 동의", R.drawable.coordit_mypage_privacy),
        Menu(Page.Settings, "앱 설정", "알림, 버전, 문의", R.drawable.coordit_mypage_settings),
    ), open)
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
    Box(
        Modifier.fillMaxWidth().background(AppColors.panel, RoundedCornerShape((10 * scale).dp))
            .padding(horizontal = (18 * scale).dp, vertical = (18 * scale).dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size((54 * scale).dp).background(AppColors.settingsValue, CircleShape), contentAlignment = Alignment.Center) {
                Image(painterResource(R.drawable.coordit_yarn), null, Modifier.size((48 * scale).dp))
            }
            Spacer(Modifier.width((12 * scale).dp))
            Column(verticalArrangement = Arrangement.spacedBy((4 * scale).dp)) {
                CoorditText("보유 실타래", CoorditTypography.gmarketBold(12 * scale).copy(color = AppColors.muted))
                CoorditText("${balance} 실타래", CoorditTypography.gmarketBold(29 * scale))
            }
        }
    }
    Pressable(
        onClick = { activity?.let(showRewardedAd) },
        enabled = charge.canWatchAd && activity != null,
        cornerRadius = 10 * scale,
        modifier = Modifier.fillMaxWidth().testTag("thread-charge-rewarded-ad"),
    ) {
        Row(
            Modifier.fillMaxWidth().height((70 * scale).dp)
                .background(Brush.verticalGradient(listOf(AppColors.chargeGradientTop, AppColors.ink, AppColors.chargeGradientEnd)))
                .padding(horizontal = (15 * scale).dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(Modifier.size((40 * scale).dp).background(Color.White.copy(alpha = .14f), RoundedCornerShape((8 * scale).dp)), contentAlignment = Alignment.Center) {
                Image(painterResource(R.drawable.coordit_recharge_play), null, Modifier.size((24 * scale).dp))
            }
            Spacer(Modifier.width((12 * scale).dp))
            CoorditText("광고 보고 실타래 충전하기", CoorditTypography.gmarketBold(16 * scale).copy(color = Color.White), Modifier.weight(1f))
            CoorditText("›", CoorditTypography.gmarketBold(26 * scale).copy(color = Color.White))
        }
    }
    charge.message?.let { status ->
        CoorditText(status, CoorditTypography.gmarketMedium(10 * scale).copy(color = AppColors.muted), Modifier.fillMaxWidth().testTag("thread-charge-status"))
    }
    if (charge.status == ThreadChargeStatus.Failed) {
        CoorditButton("광고 다시 준비하기", retryRewardedAd, modifier = Modifier.testTag("thread-charge-retry"), secondary = true)
    }
    CoorditText("패키지 구매는 출시 준비 중이에요.", CoorditTypography.gmarketMedium(10 * scale).copy(color = AppColors.muted), Modifier.fillMaxWidth().testTag("thread-charge-purchase-notice"))
    listOf(
        "5 실타래" to "1,500원",
        "10 실타래" to "2,500원",
        "20 실타래" to "4,000원",
    ).forEachIndexed { index, (amount, price) ->
        ThreadPackageRow(amount, price, highlighted = index == 1, scale = scale, tag = "thread-charge-pack-${index + 1}")
    }
}

@Composable
private fun ThreadPackageRow(amount: String, price: String, highlighted: Boolean, scale: Float, tag: String) {
    Pressable({}, enabled = false, cornerRadius = 10 * scale, modifier = Modifier.fillMaxWidth().testTag(tag)) {
        Row(
            Modifier.fillMaxWidth().height((76 * scale).dp).background(AppColors.panel, RoundedCornerShape((10 * scale).dp))
                .border(if (highlighted) (2 * scale).dp else 1.dp, if (highlighted) AppColors.warmLine else AppColors.line, RoundedCornerShape((10 * scale).dp))
                .padding(horizontal = (16 * scale).dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Image(painterResource(R.drawable.coordit_yarn), null, Modifier.size((50 * scale).dp))
            Spacer(Modifier.width((12 * scale).dp))
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
@Composable private fun MenuCard(scale: Float, menus: List<Menu>, open: (Page) -> Unit) {
    SettingsCard(scale) { menus.forEachIndexed { index, menu ->
        Pressable({ open(menu.page) }, Modifier.fillMaxWidth().testTag("mypage-${menu.page.name.lowercase()}"), cornerRadius = 0f) {
            Row(Modifier.fillMaxWidth().height((66 * scale).dp).padding(horizontal = (14 * scale).dp), verticalAlignment = Alignment.CenterVertically) {
                Image(painterResource(menu.icon), null, Modifier.size((30 * scale).dp))
                Spacer(Modifier.width((12 * scale).dp))
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy((4 * scale).dp)) {
                    CoorditText(menu.title, CoorditTypography.gmarketBold(12 * scale))
                    CoorditText(menu.subtitle, CoorditTypography.gmarketMedium(9 * scale).copy(color = AppColors.muted))
                }
                CoorditText("›", CoorditTypography.gmarketBold(22 * scale).copy(color = AppColors.muted))
            }
        }
        if (index < menus.lastIndex) SettingsDivider(scale)
    } }
}

@Composable private fun AccountPage(scale: Float, profile: UserProfile?, open: (Page) -> Unit) {
    SectionTitle("계정 정보", scale)
    SettingsCard(scale) {
        SettingsDetailRow("이름", scale, subtitle = profile?.displayName ?: "이름 없음")
        SettingsDivider(scale); SettingsDetailRow("연결 계정", scale, subtitle = profile?.email ?: "Google 계정") { SettingsValuePill("Google", scale) }
    }
    ActionRows(scale, listOf("프로필 수정" to Page.Profile, "비밀번호 변경" to Page.Password, "로그아웃" to Page.Logout, "회원탈퇴" to Page.Delete), open)
}

@Composable private fun ProfilePage(scale: Float, profile: UserProfile?, busy: Boolean, save: (String) -> Unit) {
    var name by remember(profile?.displayName) { mutableStateOf(profile?.displayName.orEmpty()) }
    SectionTitle("기본 프로필", scale)
    SettingsCard(scale) { Column(Modifier.padding((14 * scale).dp), verticalArrangement = Arrangement.spacedBy((10 * scale).dp)) {
        Box(Modifier.align(Alignment.CenterHorizontally).size((72 * scale).dp).background(AppColors.settingsValue, CircleShape), contentAlignment = Alignment.Center) {
            CoorditText(name.take(1).ifEmpty { "C" }, CoorditTypography.gmarketBold(24 * scale))
        }
        CoorditText("이름", CoorditTypography.gmarketBold(11 * scale)); CoorditField(name, { if (it.length <= 30) name = it }, "이름", placeholder = "이름을 입력해 주세요", enabled = !busy)
        CoorditText(profile?.email.orEmpty(), CoorditTypography.gmarketMedium(10 * scale).copy(color = AppColors.muted))
        CoorditButton(if (busy) "저장 중..." else "저장", { save(name) }, enabled = !busy && name.trim().isNotEmpty(), modifier = Modifier.testTag("profile-save"))
    } }
}

@Composable private fun BodyPage(scale: Float, profile: UserProfile?, body: BodyMeasurement?, edit: () -> Unit) {
    SectionTitle("저장된 신체 정보", scale)
    SettingsCard(scale) {
        ValueRow("키", body?.heightCm?.let { "${format(it)} cm" } ?: "미입력", scale); SettingsDivider(scale)
        ValueRow("몸무게", body?.weightKg?.let { "${format(it)} kg" } ?: "미입력", scale); SettingsDivider(scale)
        ValueRow("성별", when (profile?.gender?.lowercase()) { "male" -> "남성"; "female" -> "여성"; else -> profile?.gender ?: "미입력" }, scale); SettingsDivider(scale)
        ValueRow("생일", profile?.birthDate ?: profile?.birthYear?.toString() ?: "미입력", scale)
    }
    CoorditButton("키·몸무게 수정", edit, modifier = Modifier.testTag("body-edit"))
}

@Composable private fun BodyEditPage(scale: Float, body: BodyMeasurement?, busy: Boolean, save: (Double, Double) -> Unit) {
    var height by remember(body?.heightCm) { mutableStateOf(body?.heightCm?.let(::format).orEmpty()) }
    var weight by remember(body?.weightKg) { mutableStateOf(body?.weightKg?.let(::format).orEmpty()) }
    val h = height.toDoubleOrNull(); val w = weight.toDoubleOrNull(); val valid = h != null && w != null && h in 80.0..250.0 && w in 20.0..300.0
    SectionTitle("측정값", scale)
    SettingsCard(scale) { Column(Modifier.padding((14 * scale).dp), verticalArrangement = Arrangement.spacedBy((10 * scale).dp)) {
        CoorditText("키 (cm)", CoorditTypography.gmarketBold(11 * scale)); NumberField(height, { height = cleanNumber(it) }, "키")
        CoorditText("몸무게 (kg)", CoorditTypography.gmarketBold(11 * scale)); NumberField(weight, { weight = cleanNumber(it) }, "몸무게")
        CoorditText("키는 80~250 cm, 몸무게는 20~300 kg 범위로 입력해 주세요.", CoorditTypography.gmarketMedium(9 * scale).copy(color = AppColors.muted))
        CoorditButton(if (busy) "저장 중..." else "저장", { save(h!!, w!!) }, enabled = valid && !busy, modifier = Modifier.testTag("body-save"))
    } }
}

@Composable private fun NotificationsPage(scale: Float) {
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
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { enabled = it }
    var marketing by rememberPreference("marketing_notifications", false)
    SectionTitle("알림 설정", scale)
    SettingsCard(scale) {
        SettingsDetailRow("앱 알림", scale, subtitle = if (enabled) "기기에서 허용됨" else "기기에서 꺼짐") { SettingsValuePill(if (enabled) "허용" else "꺼짐", scale) }
        SettingsDivider(scale)
        SettingsDetailRow("마케팅 알림", scale, subtitle = "이벤트와 새로운 기능 소식") { SettingsToggle(marketing, { marketing = it }, "마케팅 알림", scale) }
    }
    CoorditButton(if (enabled) "기기 알림 설정 열기" else "알림 허용", {
        if (!enabled && Build.VERSION.SDK_INT >= 33) launcher.launch(Manifest.permission.POST_NOTIFICATIONS)
        else context.openAppSettings()
    }, modifier = Modifier.testTag("notification-settings"))
}

@Composable private fun PrivacyPage(scale: Float, open: (Page) -> Unit) {
    var feedback by rememberPreference("feedback_personalization", true)
    var ai by rememberPreference("ai_data_use", true)
    SectionTitle("정책 및 약관", scale)
    ActionRows(scale, listOf("개인정보 처리방침" to Page.Policy, "서비스 이용약관" to Page.Terms), open)
    SectionTitle("데이터 설정", scale)
    SettingsCard(scale) {
        SettingsDetailRow("필수 서비스 동의", scale, subtitle = "서비스 제공을 위한 필수 데이터") { SettingsValuePill("동의", scale) }
        SettingsDivider(scale)
        SettingsDetailRow("피드백 개인화", scale, subtitle = "핏 추천을 내 피드백에 맞게 조정") { SettingsToggle(feedback, { feedback = it }, "피드백 개인화", scale) }
        SettingsDivider(scale)
        SettingsDetailRow("AI 분석 데이터", scale, subtitle = "추천 품질 개선을 위한 분석") { SettingsToggle(ai, { ai = it }, "AI 분석 데이터", scale) }
    }
}

@Composable private fun AppSettingsPage(scale: Float) {
    val context = LocalContext.current
    SectionTitle("앱 정보", scale)
    SettingsCard(scale) {
        ValueRow("버전", BuildConfig.VERSION_NAME, scale); SettingsDivider(scale)
        SettingsDetailRow("고객 지원", scale, subtitle = "hyu.coordit@gmail.com")
    }
    CoorditButton("이메일로 문의하기", { context.sendSupportEmail() }, modifier = Modifier.testTag("support-email"))
    CoorditButton("알림 설정 열기", { context.openAppSettings() }, secondary = true)
}

@Composable private fun DeletePage(scale: Float, busy: Boolean, delete: () -> Unit) {
    var accepted by rememberSaveable { mutableStateOf(false) }
    InfoPage(scale, "계정을 영구 삭제합니다", "옷장, 핏 분석, 저장된 신체 정보와 계정 데이터가 모두 삭제되며 복구할 수 없어요.")
    Pressable({ accepted = !accepted }, Modifier.fillMaxWidth().testTag("delete-ack")) {
        Row(Modifier.fillMaxWidth().background(AppColors.panel, RoundedCornerShape(7.dp)).padding(15.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(22.dp).background(if (accepted) AppColors.ink else AppColors.settingsValue, RoundedCornerShape(4.dp)), contentAlignment = Alignment.Center) { if (accepted) CoorditText("✓", CoorditTypography.gmarketBold(13f).copy(color = Color.White)) }
            Spacer(Modifier.width(10.dp)); CoorditText("삭제 내용을 확인했고 동의합니다.", CoorditTypography.gmarketMedium(11 * scale))
        }
    }
    CoorditButton(if (busy) "삭제 중..." else "계정 영구 삭제", delete, enabled = accepted && !busy, modifier = Modifier.testTag("delete-account"))
}

@Composable private fun ConfirmPage(scale: Float, title: String, body: String, action: String, busy: Boolean, danger: Boolean, confirm: () -> Unit) {
    InfoPage(scale, title, body)
    CoorditButton(if (busy) "처리 중..." else action, confirm, enabled = !busy, secondary = !danger, modifier = Modifier.testTag("confirm-action"))
}
@Composable private fun InfoPage(scale: Float, title: String, body: String) { SettingsCard(scale) { Column(Modifier.padding((17 * scale).dp), verticalArrangement = Arrangement.spacedBy((9 * scale).dp)) { CoorditText(title, CoorditTypography.gmarketBold(15 * scale)); CoorditText(body, CoorditTypography.gmarketMedium(11 * scale).copy(color = AppColors.muted, lineBreak = CoorditTypography.koreanParagraph, localeList = CoorditTypography.koreanLocale)) } } }
@Composable private fun DocumentPage(scale: Float, text: String) { SettingsCard(scale) { CoorditText(text, CoorditTypography.gmarketMedium(10.5f * scale).copy(lineBreak = CoorditTypography.koreanParagraph, localeList = CoorditTypography.koreanLocale), Modifier.padding((17 * scale).dp)) } }
@Composable private fun ActionRows(scale: Float, rows: List<Pair<String, Page>>, open: (Page) -> Unit) { SettingsCard(scale) { rows.forEachIndexed { i, row -> Pressable({ open(row.second) }, Modifier.fillMaxWidth().testTag("open-${row.second.name.lowercase()}"), cornerRadius = 0f) { Row(Modifier.fillMaxWidth().height((54 * scale).dp).padding(horizontal = (14 * scale).dp), verticalAlignment = Alignment.CenterVertically) { CoorditText(row.first, CoorditTypography.gmarketBold(12 * scale), Modifier.weight(1f)); CoorditText("›", CoorditTypography.gmarketBold(21 * scale).copy(color = AppColors.muted)) } }; if (i < rows.lastIndex) SettingsDivider(scale) } } }
@Composable private fun ValueRow(title: String, value: String, scale: Float) { SettingsDetailRow(title, scale) { SettingsValuePill(value, scale) } }
@Composable private fun SectionTitle(text: String, scale: Float) { CoorditText(text, CoorditTypography.gmarketBold(12 * scale), Modifier.padding(start = (4 * scale).dp, top = (3 * scale).dp)) }
@Composable private fun SmallButton(text: String, click: () -> Unit, scale: Float, tag: String) { Pressable(click, Modifier.testTag(tag)) { Box(Modifier.background(AppColors.ink, CircleShape).padding(horizontal = (15 * scale).dp, vertical = (9 * scale).dp)) { CoorditText(text, CoorditTypography.gmarketBold(10 * scale).copy(color = Color.White)) } } }
@Composable private fun StatusPanel(text: String, error: Boolean, scale: Float) { Box(Modifier.fillMaxWidth().background(if (error) AppColors.danger.copy(alpha = .12f) else AppColors.settingsValue, RoundedCornerShape(7.dp)).padding((12 * scale).dp)) { CoorditText(text, CoorditTypography.gmarketMedium(10 * scale).copy(color = if (error) AppColors.danger else AppColors.ink)) } }
@Composable private fun NumberField(value: String, change: (String) -> Unit, label: String) { androidx.compose.foundation.text.BasicTextField(value, change, Modifier.fillMaxWidth().heightIn(min = 48.dp).background(AppColors.settingsField, RoundedCornerShape(7.dp)).padding(13.dp).semantics { contentDescription = label }, textStyle = CoorditTypography.gmarketMedium(13f), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal), singleLine = true) }
@Composable private fun CoorditDialog(title: String, body: String, dismiss: () -> Unit) { androidx.compose.ui.window.Dialog(onDismissRequest = dismiss) { Column(Modifier.fillMaxWidth().background(AppColors.panel, RoundedCornerShape(11.dp)).padding(24.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) { CoorditText(title, CoorditTypography.gmarketBold(19f)); CoorditText(body, CoorditTypography.gmarketMedium(12f)); CoorditButton("확인", dismiss) } } }

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

private val policyText = """개인정보 처리방침

Coordit은 핏 추천과 옷장 서비스를 제공하기 위해 계정 정보, 신체 측정값, 의류 정보와 서비스 이용 기록을 처리합니다.

수집한 정보는 회원 식별, 맞춤 핏 분석, 서비스 운영과 품질 개선에 사용합니다. 법령상 보관 의무가 있는 경우를 제외하고 회원탈퇴 시 지체 없이 삭제합니다.

이용자는 개인정보 열람, 정정, 삭제와 처리 정지를 요청할 수 있습니다. 문의: hyu.coordit@gmail.com"""
private val termsText = """서비스 이용약관

Coordit은 사용자가 입력한 신체 정보와 의류 측정값을 바탕으로 참고용 핏 추천을 제공합니다. 실제 착용감은 소재, 재단과 개인의 선호에 따라 달라질 수 있습니다.

사용자는 정확한 정보를 입력하고 자신의 계정을 안전하게 관리해야 합니다. 다른 사람의 권리를 침해하거나 서비스를 방해하는 방식으로 사용할 수 없습니다.

서비스 내용은 개선 과정에서 변경될 수 있으며 중요한 변경은 앱 또는 등록된 연락처로 안내합니다."""
