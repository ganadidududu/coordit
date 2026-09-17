package com.inseong.coordit.ui.auth

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.inseong.coordit.R
import com.inseong.coordit.ui.components.ContinuousRoundedShape
import com.inseong.coordit.ui.components.SettingsDivider
import com.inseong.coordit.ui.components.SharedAppBackground
import com.inseong.coordit.ui.components.coorditReferenceTopInset
import com.inseong.coordit.ui.components.coorditReferenceBottomInset
import com.inseong.coordit.ui.components.coorditShadow
import com.inseong.coordit.ui.theme.AppColors
import com.inseong.coordit.ui.theme.AppDimensions
import com.inseong.coordit.ui.theme.CoorditTypography

/** Geometry and copy from CoorditSplashAuthenticationSheet.swift. */
private object AuthenticationDesign {
    const val ContentWidth = 370f
    const val TopInset = 28f
    const val TitleTopInset = 24f
    const val BottomInset = 36f
    const val TitleHeight = 72f
    const val TitleRadius = 11f
    const val TitleInset = 18f
    const val TitleFont = 24f
    const val TitleToIntroduction = 30f
    const val IntroductionGap = 8f
    const val IntroductionFont = 26f
    const val BodyFont = 12f
    const val IntroductionToProviders = 22f
    const val CardRadius = 7f
    const val CardPadding = 12f
    const val ProviderHeight = 58f
    const val ProviderInset = 15f
    const val ProviderGap = 12f
    const val MarkSize = 28f
    const val MarkFont = 16f
    const val ProviderFont = 14f
    const val ArrowSize = 13f
    const val ProvidersToLegal = 20f
    const val LegalFont = 10f
    const val PressedScale = .98f
    const val PressedOpacity = .9f
    const val PressedOverlay = .1f
}

@Composable
fun AuthenticationScreen(
    busy: Boolean,
    error: String?,
    onGoogle: () -> Unit,
    onApple: () -> Unit,
    modifier: Modifier = Modifier,
) {
    BoxWithConstraints(modifier.fillMaxSize().testTag("coordit-screen-splash")) {
        val scale = (maxWidth.value / AppDimensions.designWidth).coerceAtLeast(.1f)
        SharedAppBackground(scale)
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Column(
                Modifier.width((AuthenticationDesign.ContentWidth * scale).dp)
                    .padding(top = coorditReferenceTopInset(scale) + ((AuthenticationDesign.TopInset + AuthenticationDesign.TitleTopInset) * scale).dp,
                        bottom = coorditReferenceBottomInset(scale) + (AuthenticationDesign.BottomInset * scale).dp),
            ) {
                AuthenticationTitle(scale)
                Spacer(Modifier.height((AuthenticationDesign.TitleToIntroduction * scale).dp))
                BasicText("계속하려면\n로그인하세요",
                    Modifier.semantics { heading() },
                    style = CoorditTypography.gmarketBold(AuthenticationDesign.IntroductionFont * scale)
                        .copy(lineHeight = (30f * scale).sp))
                Spacer(Modifier.height((AuthenticationDesign.IntroductionGap * scale).dp))
                BasicText("Google 또는 Apple 계정으로\n내 핏 기록을 이어갈 수 있어요.",
                    style = CoorditTypography.gmarketMedium(AuthenticationDesign.BodyFont * scale)
                        .copy(color = AppColors.muted, lineHeight = (15f * scale).sp))
                Spacer(Modifier.height((AuthenticationDesign.IntroductionToProviders * scale).dp))
                val cardShape = ContinuousRoundedShape((AuthenticationDesign.CardRadius * scale).dp)
                Column(Modifier.fillMaxWidth()
                    .coorditShadow(Color.Black.copy(alpha = .035f), (9f * scale).dp, cardShape, (4f * scale).dp)
                    .background(AppColors.panel, cardShape)
                    .clip(cardShape)
                    .border(1.dp, AppColors.line.copy(alpha = .7f), cardShape)
                    .padding(vertical = (AuthenticationDesign.CardPadding * scale).dp)
                    .testTag("coordit-splash-auth-sheet")) {
                    ProviderRow("Google로 계속하기", false, scale, !busy, onGoogle)
                    SettingsDivider(scale)
                    ProviderRow("Apple로 계속하기", true, scale, !busy, onApple)
                }
                Spacer(Modifier.height((AuthenticationDesign.ProvidersToLegal * scale).dp))
                BasicText("계속하면 이용약관 및 개인정보 처리방침에 동의하게 됩니다.",
                    style = CoorditTypography.gmarketMedium(AuthenticationDesign.LegalFont * scale)
                        .copy(color = AppColors.muted, lineHeight = (14f * scale).sp))
                if (busy) {
                    Spacer(Modifier.height((16f * scale).dp))
                    BasicText("로그인 중이에요. 잠시만 기다려 주세요.",
                        modifier = Modifier.testTag("authentication-loading").semantics {
                            liveRegion = LiveRegionMode.Polite
                            progressBarRangeInfo = ProgressBarRangeInfo.Indeterminate
                        },
                        style = CoorditTypography.gmarketMedium(12f * scale))
                } else if (!error.isNullOrBlank()) {
                    Spacer(Modifier.height((16f * scale).dp))
                    BasicText(error,
                        modifier = Modifier.testTag("authentication-error").semantics {
                            liveRegion = LiveRegionMode.Assertive
                            error(error)
                        },
                        style = CoorditTypography.gmarketMedium(12f * scale)
                            .copy(color = AppColors.danger, lineHeight = (18f * scale).sp))
                }
            }
        }
    }
}

@Composable
private fun AuthenticationTitle(scale: Float) {
    val shape = ContinuousRoundedShape((AuthenticationDesign.TitleRadius * scale).dp)
    Box(Modifier.fillMaxWidth().heightIn(min = (AuthenticationDesign.TitleHeight * scale).dp)
        .coorditShadow(Color.Black.copy(alpha = .045f), (10f * scale).dp, shape, (4f * scale).dp)
        .background(AppColors.panel, shape)
        .border(1.dp, AppColors.line.copy(alpha = .72f), shape)
        .padding(horizontal = (AuthenticationDesign.TitleInset * scale).dp, vertical = (12f * scale).dp),
        contentAlignment = Alignment.CenterStart) {
        BasicText("로그인 / 회원가입", style = CoorditTypography.gmarketBold(AuthenticationDesign.TitleFont * scale)
            .copy(color = Color.Black))
    }
}

@Composable
private fun ProviderRow(title: String, apple: Boolean, scale: Float, enabled: Boolean, onClick: () -> Unit) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val pressScale by animateFloatAsState(
        if (pressed && enabled) AuthenticationDesign.PressedScale else 1f, tween(35), label = "provider press scale")
    val pressOpacity by animateFloatAsState(
        if (pressed && enabled) AuthenticationDesign.PressedOpacity else 1f, tween(35), label = "provider press opacity")
    val overlayOpacity by animateFloatAsState(
        if (pressed && enabled) AuthenticationDesign.PressedOverlay else 0f, tween(35), label = "provider press overlay")
    val shape = ContinuousRoundedShape((AuthenticationDesign.CardRadius * scale).dp)
    Box(Modifier.fillMaxWidth().graphicsLayer {
        scaleX = pressScale
        scaleY = pressScale
        alpha = pressOpacity
    }.clip(shape).clickable(interactionSource = interaction, indication = null, enabled = enabled,
        role = Role.Button, onClick = onClick)
        .semantics(mergeDescendants = true) { contentDescription = title }
        .testTag(if (apple) "splash-auth-apple" else "splash-auth-google")) {
        Row(Modifier.fillMaxWidth().heightIn(min = (AuthenticationDesign.ProviderHeight * scale).dp)
            .padding(horizontal = (AuthenticationDesign.ProviderInset * scale).dp, vertical = (8f * scale).dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy((AuthenticationDesign.ProviderGap * scale).dp)) {
            Box(Modifier.size((AuthenticationDesign.MarkSize * scale).dp)
                .background(if (apple) AppColors.ink else AppColors.settingsField, CircleShape)
                .clearAndSetSemantics {}, contentAlignment = Alignment.Center) {
                if (apple) {
                    // Official, unmodified cross-platform sign-in button asset; provenance is recorded in android/apple-sign-in-logo-PROVENANCE.md.
                    Image(painterResource(R.drawable.apple_sign_in_logo), contentDescription = null,
                        modifier = Modifier.fillMaxSize())
                } else {
                    BasicText("G", style = TextStyle(fontFamily = FontFamily.SansSerif, fontWeight = FontWeight.Bold,
                        fontSize = (AuthenticationDesign.MarkFont * scale).sp, color = AppColors.blue))
                }
            }
            BasicText(title, modifier = Modifier.weight(1f).clearAndSetSemantics {},
                style = CoorditTypography.gmarketBold(AuthenticationDesign.ProviderFont * scale))
            Canvas(Modifier.size((AuthenticationDesign.ArrowSize * scale).dp).clearAndSetSemantics {}) {
                val center = size.height * .5f
                val end = size.width * .87f
                val stroke = 1.6f * scale * density
                drawLine(AppColors.muted, Offset(size.width * .08f, center), Offset(end, center), stroke, StrokeCap.Round)
                drawLine(AppColors.muted, Offset(size.width * .53f, size.height * .17f), Offset(end, center), stroke, StrokeCap.Round)
                drawLine(AppColors.muted, Offset(end, center), Offset(size.width * .53f, size.height * .83f), stroke, StrokeCap.Round)
            }
        }
        Box(Modifier.matchParentSize().background(Color.Black.copy(alpha = overlayOpacity)))
    }
}
