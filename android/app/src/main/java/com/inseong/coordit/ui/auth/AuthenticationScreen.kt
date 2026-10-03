package com.inseong.coordit.ui.auth

import android.app.Activity
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.ProgressBarRangeInfo
import androidx.compose.ui.semantics.error
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.progressBarRangeInfo
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.view.WindowInsetsControllerCompat
import com.inseong.coordit.R
import com.inseong.coordit.ui.components.Pressable
import com.inseong.coordit.ui.components.SplashBackground
import com.inseong.coordit.ui.theme.AppColors
import com.inseong.coordit.ui.theme.CoorditTypography

/** Mirrors the production iOS authentication sheet in CoorditSplashAuthenticationSheet.swift. */
private object AuthenticationDesign {
    const val designWidth = 402f
    const val sheetHeight = 450f
    const val sheetCornerRadius = 28f
    const val horizontalInset = 24f
    const val topInset = 22f
    const val bottomInset = 18f
    const val titleSize = 22f
    const val subtitleSize = 13f
    const val titleToSubtitleSpacing = 10f
    const val subtitleToProviderSpacing = 28f
    const val providerStackSpacing = 12f
    const val providerHeight = 56f
    const val providerHorizontalInset = 16f
    const val providerCornerRadius = 16f
    const val providerTitleSize = 14f
    const val providerMarkFrame = 28f
    const val secondaryActionHeight = 44f
    const val emailEntrySize = 12f
    const val statusTopSpacing = 18f
    const val statusSize = 11.5f
    const val footerMinimumSpacing = 16f
    const val legalSize = 11f
    val providerSurface = Color(0xFFF6F7FA)
    val errorForeground = Color(0xFF9E0A14)
}

private enum class AuthenticationMode { Providers, Email }

@Composable
fun AuthenticationScreen(
    busy: Boolean,
    error: String?,
    onGoogle: () -> Unit,
    onApple: () -> Unit,
    onGuest: () -> Unit,
    onEmail: (String, String) -> Unit,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var mode by rememberSaveable { mutableStateOf(AuthenticationMode.Providers) }
    var email by rememberSaveable { mutableStateOf("") }
    var password by rememberSaveable { mutableStateOf("") }
    val leave = {
        if (mode == AuthenticationMode.Email) {
            mode = AuthenticationMode.Providers
            password = ""
        } else {
            onDismiss()
        }
    }
    BackHandler(enabled = !busy, onBack = leave)
    AuthenticationStatusBarContrast()

    BoxWithConstraints(modifier.fillMaxSize().testTag("coordit-screen-splash")) {
        val scale = (maxWidth.value / AuthenticationDesign.designWidth).coerceAtLeast(.1f)
        SplashBackground(Modifier.fillMaxSize())
        Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = .12f)))
        Column(
            Modifier.align(Alignment.BottomCenter)
                .fillMaxWidth()
                .imePadding()
                .height((AuthenticationDesign.sheetHeight * scale).dp)
                .background(
                    Color.White,
                    RoundedCornerShape(
                        topStart = (AuthenticationDesign.sheetCornerRadius * scale).dp,
                        topEnd = (AuthenticationDesign.sheetCornerRadius * scale).dp,
                    ),
                )
                .padding(
                    start = (AuthenticationDesign.horizontalInset * scale).dp,
                    end = (AuthenticationDesign.horizontalInset * scale).dp,
                    top = (AuthenticationDesign.topInset * scale).dp,
                    bottom = (AuthenticationDesign.bottomInset * scale).dp,
                )
                .testTag("coordit-splash-auth-sheet"),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(
                Modifier.width((36 * scale).dp).height((4 * scale).dp)
                    .background(AppColors.ink.copy(alpha = .18f), CircleShape),
            )
            Spacer(Modifier.height((10 * scale).dp))
            BasicText(
                "coordit 시작하기",
                Modifier.semantics { },
                style = CoorditTypography.gmarketMedium(AuthenticationDesign.titleSize * scale)
                    .copy(color = AppColors.ink),
            )
            BasicText(
                if (mode == AuthenticationMode.Providers) "비회원으로 시작하거나 계정을 연결하세요." else "이메일과 비밀번호를 입력하세요.",
                Modifier.padding(top = (AuthenticationDesign.titleToSubtitleSpacing * scale).dp),
                style = CoorditTypography.gmarketMedium(AuthenticationDesign.subtitleSize * scale)
                    .copy(color = AppColors.ink.copy(alpha = .6f), textAlign = TextAlign.Center),
            )
            Spacer(Modifier.height((AuthenticationDesign.subtitleToProviderSpacing * scale).dp))

            if (mode == AuthenticationMode.Providers) {
                ProviderChoices(scale, busy, onGoogle, onApple, onGuest) { mode = AuthenticationMode.Email }
            } else {
                EmailLoginForm(
                    scale = scale,
                    email = email,
                    password = password,
                    busy = busy,
                    onEmailChange = { email = it },
                    onPasswordChange = { password = it },
                    onSubmit = { onEmail(email.trim(), password) },
                    onBack = { mode = AuthenticationMode.Providers; password = "" },
                )
            }

            if (busy) {
                Canvas(
                    Modifier.padding(top = (AuthenticationDesign.statusTopSpacing * scale).dp)
                        .size((20 * scale).dp)
                        .testTag("authentication-loading")
                        .semantics {
                            liveRegion = LiveRegionMode.Polite
                            progressBarRangeInfo = ProgressBarRangeInfo.Indeterminate
                        },
                ) {
                    drawArc(
                        color = AppColors.ink,
                        startAngle = -72f,
                        sweepAngle = 286f,
                        useCenter = false,
                        style = Stroke(width = 2f * scale * density, cap = StrokeCap.Round),
                    )
                }
            } else if (!error.isNullOrBlank()) {
                BasicText(
                    error,
                    Modifier.fillMaxWidth().padding(top = (AuthenticationDesign.statusTopSpacing * scale).dp)
                        .testTag("splash-auth-error")
                        .semantics { liveRegion = LiveRegionMode.Assertive; error(error) },
                    style = CoorditTypography.gmarketMedium(AuthenticationDesign.statusSize * scale)
                        .copy(color = AuthenticationDesign.errorForeground, textAlign = TextAlign.Center, lineHeight = (16 * scale).sp),
                )
            }

            Spacer(Modifier.weight(1f, fill = true))
            BasicText(
                "계속하면 coordit의 이용약관과 개인정보 처리방침에 동의하게 됩니다.",
                Modifier.fillMaxWidth().testTag("splash-auth-legal"),
                style = CoorditTypography.gmarketMedium(AuthenticationDesign.legalSize * scale)
                    .copy(color = AppColors.ink.copy(alpha = .58f), textAlign = TextAlign.Center, lineHeight = (14 * scale).sp),
            )
        }
    }
}

@Composable
private fun AuthenticationStatusBarContrast() {
    val view = LocalView.current
    DisposableEffect(view) {
        val window = (view.context as? Activity)?.window ?: return@DisposableEffect onDispose {}
        val controller = WindowInsetsControllerCompat(window, view)
        val previous = controller.isAppearanceLightStatusBars
        controller.isAppearanceLightStatusBars = false
        onDispose { controller.isAppearanceLightStatusBars = previous }
    }
}

@Composable
private fun ProviderChoices(
    scale: Float,
    busy: Boolean,
    onGoogle: () -> Unit,
    onApple: () -> Unit,
    onGuest: () -> Unit,
    onEmail: () -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy((AuthenticationDesign.providerStackSpacing * scale).dp)) {
        SocialProviderButton(
            title = "Google로 계속하기",
            enabled = !busy,
            scale = scale,
            tag = "splash-auth-google",
            onClick = onGoogle,
        ) {
            Box(
                Modifier.size((AuthenticationDesign.providerMarkFrame * scale).dp)
                    .background(Color.White, CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                BasicText(
                    "G",
                    style = TextStyle(
                        fontFamily = FontFamily.SansSerif,
                        fontWeight = FontWeight.Bold,
                        fontSize = (16 * scale).sp,
                        color = Color(0xFF4273D4),
                    ),
                )
            }
        }
        AppleProviderButton(scale, !busy, onApple)
        OutlineProviderButton("비회원으로 로그인하기", "splash-auth-guest", scale, !busy, onGuest)
        SecondaryActionButton("이메일로 로그인", "splash-auth-email", scale, !busy, onEmail)
    }
}

@Composable
private fun SocialProviderButton(
    title: String,
    enabled: Boolean,
    scale: Float,
    tag: String,
    onClick: () -> Unit,
    mark: @Composable () -> Unit,
) {
    val shape = RoundedCornerShape((AuthenticationDesign.providerCornerRadius * scale).dp)
    Pressable(onClick, Modifier.fillMaxWidth().testTag(tag), enabled, AuthenticationDesign.providerCornerRadius * scale) {
        Row(
            Modifier.fillMaxWidth().height((AuthenticationDesign.providerHeight * scale).dp)
                .background(AuthenticationDesign.providerSurface, shape)
                .border(1.dp, AppColors.ink.copy(alpha = .09f), shape)
                .padding(horizontal = (AuthenticationDesign.providerHorizontalInset * scale).dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy((12 * scale).dp),
        ) {
            mark()
            BasicText(
                title,
                style = CoorditTypography.gmarketMedium(AuthenticationDesign.providerTitleSize * scale)
                    .copy(color = AppColors.ink),
            )
        }
    }
}

@Composable
private fun AppleProviderButton(scale: Float, enabled: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape((AuthenticationDesign.providerCornerRadius * scale).dp)
    Pressable(onClick, Modifier.fillMaxWidth().testTag("splash-auth-apple"), enabled, AuthenticationDesign.providerCornerRadius * scale) {
        Row(
            Modifier.fillMaxWidth().height((AuthenticationDesign.providerHeight * scale).dp)
                .background(AppColors.ink, shape)
                .padding(horizontal = (AuthenticationDesign.providerHorizontalInset * scale).dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy((12 * scale).dp),
        ) {
            Image(
                painterResource(R.drawable.apple_sign_in_logo),
                contentDescription = null,
                modifier = Modifier.size((AuthenticationDesign.providerMarkFrame * scale).dp),
            )
            BasicText(
                "Apple로 계속하기",
                style = CoorditTypography.gmarketMedium(AuthenticationDesign.providerTitleSize * scale)
                    .copy(color = Color.White),
            )
        }
    }
}

@Composable
private fun OutlineProviderButton(title: String, tag: String, scale: Float, enabled: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape((AuthenticationDesign.providerCornerRadius * scale).dp)
    Pressable(onClick, Modifier.fillMaxWidth().testTag(tag), enabled, AuthenticationDesign.providerCornerRadius * scale) {
        Box(
            Modifier.fillMaxWidth().height((AuthenticationDesign.providerHeight * scale).dp)
                .background(Color.White, shape)
                .border(1.dp, AppColors.ink.copy(alpha = .2f), shape),
            contentAlignment = Alignment.Center,
        ) {
            BasicText(title, style = CoorditTypography.gmarketMedium(AuthenticationDesign.providerTitleSize * scale).copy(color = AppColors.ink))
        }
    }
}

@Composable
private fun SecondaryActionButton(title: String, tag: String, scale: Float, enabled: Boolean, onClick: () -> Unit) {
    Pressable(onClick, Modifier.fillMaxWidth().height((AuthenticationDesign.secondaryActionHeight * scale).dp).testTag(tag), enabled, 8 * scale) {
        BasicText(
            title,
            style = CoorditTypography.gmarketMedium(AuthenticationDesign.emailEntrySize * scale)
                .copy(color = AppColors.ink.copy(alpha = .72f)),
        )
    }
}

@Composable
private fun EmailLoginForm(
    scale: Float,
    email: String,
    password: String,
    busy: Boolean,
    onEmailChange: (String) -> Unit,
    onPasswordChange: (String) -> Unit,
    onSubmit: () -> Unit,
    onBack: () -> Unit,
) {
    val canSubmit = email.trim().isNotEmpty() && password.isNotEmpty()
    Column(verticalArrangement = Arrangement.spacedBy((AuthenticationDesign.providerStackSpacing * scale).dp)) {
        AuthField(
            value = email,
            placeholder = "이메일",
            enabled = !busy,
            tag = "splash-auth-email-field",
            scale = scale,
            onValueChange = onEmailChange,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email, imeAction = ImeAction.Next),
        )
        AuthField(
            value = password,
            placeholder = "비밀번호",
            enabled = !busy,
            tag = "splash-auth-password-field",
            scale = scale,
            onValueChange = onPasswordChange,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = ImeAction.Go),
            keyboardActions = KeyboardActions(onGo = { if (canSubmit) onSubmit() }),
            visualTransformation = PasswordVisualTransformation(),
        )
        OutlineProviderButton(
            if (busy) "로그인 중…" else "이메일로 로그인",
            "splash-auth-email-submit",
            scale,
            enabled = canSubmit && !busy,
            onClick = onSubmit,
        )
        SecondaryActionButton("다른 방법으로 로그인", "splash-auth-email-back", scale, !busy, onBack)
    }
}

@Composable
private fun AuthField(
    value: String,
    placeholder: String,
    enabled: Boolean,
    tag: String,
    scale: Float,
    onValueChange: (String) -> Unit,
    keyboardOptions: KeyboardOptions,
    keyboardActions: KeyboardActions = KeyboardActions.Default,
    visualTransformation: VisualTransformation = VisualTransformation.None,
) {
    val shape = RoundedCornerShape((AuthenticationDesign.providerCornerRadius * scale).dp)
    BasicTextField(
        value = value,
        onValueChange = onValueChange,
        modifier = Modifier.fillMaxWidth().height((AuthenticationDesign.providerHeight * scale).dp)
            .clip(shape).background(AuthenticationDesign.providerSurface).padding(horizontal = (AuthenticationDesign.providerHorizontalInset * scale).dp)
            .testTag(tag),
        enabled = enabled,
        singleLine = true,
        textStyle = CoorditTypography.gmarketMedium(AuthenticationDesign.providerTitleSize * scale).copy(color = AppColors.ink),
        cursorBrush = SolidColor(AppColors.ink),
        keyboardOptions = keyboardOptions,
        keyboardActions = keyboardActions,
        visualTransformation = visualTransformation,
        decorationBox = { inner ->
            Box(contentAlignment = Alignment.CenterStart) {
                if (value.isEmpty()) {
                    BasicText(
                        placeholder,
                        style = CoorditTypography.gmarketMedium(AuthenticationDesign.providerTitleSize * scale)
                            .copy(color = AppColors.ink.copy(alpha = .5f)),
                    )
                }
                inner()
            }
        },
    )
}
