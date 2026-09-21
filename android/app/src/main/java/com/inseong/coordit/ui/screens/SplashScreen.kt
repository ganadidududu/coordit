package com.inseong.coordit.ui.screens

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.scale
import androidx.compose.ui.layout.layout
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.platform.LocalDensity
import com.inseong.coordit.ui.components.coorditShadow
import com.inseong.coordit.ui.components.ContinuousRoundedShape
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.inseong.coordit.ui.components.CoorditLogo
import com.inseong.coordit.ui.components.SplashBackground
import com.inseong.coordit.ui.theme.AppColors
import com.inseong.coordit.ui.theme.CoorditTypography
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** Values from CoorditSplashScreen.swift; geometry is expressed in the 402pt design space. */
private object SplashMetrics {
    const val DesignWidth = 402f
    const val TaglineTop = 232f
    const val TaglineFont = 24.462f
    const val DividerTop = 48f
    const val DividerHeight = 100f
    const val DividerWidth = 0.8f
    const val LogoTop = 35f
    const val LogoScale = 1.432f
    const val LogoWidth = 199.032f
    const val LogoHeight = 55.574f
    const val EntryWidth = 210f
    const val EntryHeight = 52f
    const val EntryRadius = 15f
    const val EntryFont = 17.5f
    const val EntryVerticalPosition = 0.935f
    const val HintVerticalPosition = 0.82f
}

enum class SplashPresentation { FirstInstall, ReturningUser }

@Composable
fun SplashScreen(
    presentation: SplashPresentation,
    onAuthenticationRequested: () -> Unit,
    onEnter: () -> Unit,
    modifier: Modifier = Modifier,
    reduceMotion: Boolean = false,
) {
    val tagline = remember { Animatable(0f) }
    val divider = remember { Animatable(0f) }
    val logo = remember { Animatable(0f) }
    val easeOut = remember { CubicBezierEasing(0f, 0f, 0.58f, 1f) }
    val easeInOut = remember { CubicBezierEasing(0.42f, 0f, 0.58f, 1f) }
    LaunchedEffect(reduceMotion) {
        if (reduceMotion) {
            tagline.snapTo(1f)
            divider.snapTo(1f)
            logo.snapTo(1f)
        } else {
            launch { tagline.animateTo(1f, tween(520, easing = easeOut)) }
            launch { delay(420); divider.animateTo(1f, tween(860, easing = easeInOut)) }
            launch { delay(1_240); logo.animateTo(1f, tween(220, easing = easeOut)) }
        }
    }
    BoxWithConstraints(modifier.fillMaxSize().testTag("splash-screen")) {
        val scale = (maxWidth.value / SplashMetrics.DesignWidth).coerceAtLeast(0.1f)
        val screenHeight = maxHeight
        val density = LocalDensity.current
        val returning = presentation == SplashPresentation.ReturningUser
        val interaction = remember { MutableInteractionSource() }
        SplashBackground(Modifier.fillMaxSize())
        Box(
            Modifier.fillMaxSize().then(
                if (returning) Modifier.clickable(
                    interactionSource = interaction,
                    indication = null,
                    role = Role.Button,
                    onClickLabel = "홈으로 이동",
                    onClick = onEnter,
                ) else Modifier,
            ).testTag("splash-enter-surface"),
        ) {
            Column(Modifier.align(Alignment.TopCenter), horizontalAlignment = Alignment.CenterHorizontally) {
                Spacer(Modifier.height((SplashMetrics.TaglineTop * scale).dp))
                BasicText(
                    "당신을 위한 디지털 옷장",
                    Modifier.alpha(tagline.value).offset(y = (12f * scale * (1f - tagline.value)).dp)
                        .testTag("splash-tagline"),
                    style = CoorditTypography.gmarketMedium(SplashMetrics.TaglineFont * scale)
                        .copy(color = Color.White, textAlign = TextAlign.Center),
                    maxLines = 1,
                )
                Spacer(Modifier.height((SplashMetrics.DividerTop * scale).dp))
                Box(Modifier.height((SplashMetrics.DividerHeight * scale).dp)) {
                    Box(
                        Modifier.width((SplashMetrics.DividerWidth * scale).coerceAtLeast(0.5f).dp)
                            .height((SplashMetrics.DividerHeight * scale * divider.value).coerceAtLeast(0.5f).dp)
                            .alpha(if (divider.value > 0f) 1f else 0f)
                            .background(Color.White.copy(alpha = 0.92f), RoundedCornerShape(50)),
                    )
                }
                Spacer(Modifier.height((SplashMetrics.LogoTop * scale).dp))
                CoorditLogo(
                    scale = scale * SplashMetrics.LogoScale,
                    color = Color.White,
                    modifier = Modifier.size((SplashMetrics.LogoWidth * scale).dp, (SplashMetrics.LogoHeight * scale).dp)
                        .offset(x = (4.08f * scale * SplashMetrics.LogoScale).dp)
                        .alpha(logo.value).scale(0.94f + 0.06f * logo.value).testTag("splash-logo"),
                )
            }
            if (returning) {
                BasicText(
                    "화면을 클릭해주세요",
                    modifier = Modifier.align(Alignment.TopCenter)
                        .offset(y = screenHeight * SplashMetrics.HintVerticalPosition + (8f * scale * (1f - logo.value)).dp)
                        .layout { measurable, constraints ->
                            val text = measurable.measure(constraints)
                            layout(text.width, 0) { text.placeRelative(0, -text.height / 2) }
                        }
                        .alpha(logo.value).testTag("splash-tap-hint"),
                    style = CoorditTypography.gmarketMedium(14f * scale)
                        .copy(
                            color = AppColors.ink.copy(alpha = 0.62f),
                            shadow = Shadow(Color.White.copy(alpha = 0.22f),
                                Offset(0f, with(density) { (scale).dp.toPx() }),
                                with(density) { (3f * scale).dp.toPx() }),
                        ),
                )
            } else {
                val shape = ContinuousRoundedShape((SplashMetrics.EntryRadius * scale).dp)
                Box(
                    Modifier.align(Alignment.TopCenter)
                        .offset(y = screenHeight * SplashMetrics.EntryVerticalPosition - (SplashMetrics.EntryHeight * scale / 2f).dp + (8f * scale * (1f - logo.value)).dp)
                        .size((SplashMetrics.EntryWidth * scale).dp, (SplashMetrics.EntryHeight * scale).dp)
                        .alpha(logo.value)
                        .coorditShadow(AppColors.ink.copy(alpha = 0.12f), (16f * scale).dp,
                            shape, (8f * scale).dp)
                        .background(Color.White, shape)
                        .clickable(
                            interactionSource = remember { MutableInteractionSource() },
                            indication = null,
                            role = Role.Button,
                            onClick = onAuthenticationRequested,
                        ).testTag("splash-signup-entry"),
                    contentAlignment = Alignment.Center,
                ) {
                    BasicText("로그인/회원가입", style = CoorditTypography.gmarketMedium(SplashMetrics.EntryFont * scale).copy(color = AppColors.ink))
                }
            }
        }
    }
}
