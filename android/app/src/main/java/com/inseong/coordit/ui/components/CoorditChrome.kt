package com.inseong.coordit.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.*
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.layout
import kotlin.math.roundToInt
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.inseong.coordit.R
import com.inseong.coordit.ui.theme.*

@Composable
fun SharedAppBackground(scale: Float, modifier: Modifier = Modifier) {
    Box(modifier.fillMaxSize().background(AppColors.appBackground)) {
        Box(Modifier.fillMaxWidth().height((AppDimensions.topChromeHeight * scale).dp)
            .background(Brush.verticalGradient(*AppGradients.topChrome)))
        Box(Modifier.align(Alignment.BottomCenter).fillMaxWidth().height((AppDimensions.bottomChromeHeight * scale).dp)
            .background(Brush.verticalGradient(*AppGradients.bottomChrome))) {
            Canvas(Modifier.matchParentSize().graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }) {
                drawRect(Brush.horizontalGradient(*AppGradients.bottomChromeContour))
                drawRect(Brush.verticalGradient(*AppGradients.bottomChromeContourMask), blendMode = BlendMode.DstIn)
            }
        }
    }
}

@Composable
fun SplashBackground(modifier: Modifier = Modifier) {
    Image(painterResource(R.drawable.coordit_splash_reference), contentDescription = null,
        modifier = modifier.fillMaxSize().background(AppColors.ink), contentScale = ContentScale.Crop)
}

@Composable
fun CoorditLogo(scale: Float, white: Boolean = true, modifier: Modifier = Modifier, color: Color = if (white) AppColors.foreground else AppColors.ink) {
    val normal = CoorditTypography.climate2019(22.565f * scale).copy(color = color, letterSpacing = (-4.513f * scale).sp)
    Box(modifier.size((139 * scale).dp, (38.8117f * scale).dp).clearAndSetSemantics { contentDescription = "COORDIT" }) {
        KernedLogoText(AnnotatedString("C"), normal, Modifier.offset((3.159f * scale).dp, (9.159f * scale).dp))
        val tailStyles = listOf(
            "R" to normal,
            "D" to CoorditTypography.climate2030(23.016f * scale).copy(color = color, letterSpacing = (-4.1429f * scale).sp),
            "I" to normal.copy(letterSpacing = (-3.3847f * scale).sp),
            "T" to normal,
        )
        // SwiftUI applies each run's kern after its glyph; Android mixes adjacent span spacing.
        Row(Modifier.offset((63.159f * scale).dp, (9.159f * scale).dp).clipToBounds()) {
            tailStyles.forEach { (glyph, glyphStyle) ->
                BasicText(glyph, Modifier.alignByBaseline().layout { measurable, constraints ->
                    val measured = measurable.measure(constraints)
                    val advance = measured.width + glyphStyle.letterSpacing.toPx().roundToInt()
                    layout(advance.coerceAtLeast(0), measured.height) { measured.placeRelative(0, 0) }
                }, style = glyphStyle.copy(letterSpacing = 0.sp), softWrap = false, overflow = TextOverflow.Visible)
            }
        }
        Image(painterResource(R.drawable.figma_logo_o1), null,
            Modifier.offset((26.1815f * scale).dp, (12.1851f * scale).dp).size((18.5032f * scale).dp, (14.8932f * scale).dp),
            colorFilter = ColorFilter.tint(color), contentScale = ContentScale.FillBounds)
        Image(painterResource(R.drawable.figma_logo_o2), null,
            Modifier.offset((45.5812f * scale).dp, (12.1851f * scale).dp).size((18.5032f * scale).dp, (14.8932f * scale).dp),
            colorFilter = ColorFilter.tint(color), contentScale = ContentScale.FillBounds)
    }
}

@Composable
fun CoorditHeader(scale: Float, onProfileTap: () -> Unit, modifier: Modifier = Modifier) {
    Row(modifier.size((333 * scale).dp, (38.8117f * scale).dp), verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween) {
        Pressable(onProfileTap, Modifier.size((30 * scale).dp).semantics { contentDescription = "My" }) {
            Image(painterResource(R.drawable.figma_top_my), null, Modifier.size((30 * scale).dp))
        }
        CoorditLogo(scale)
        Image(painterResource(R.drawable.figma_top_sun), "Weather", Modifier.size((30 * scale).dp))
    }
}

enum class CoorditTab(val title: String, val resource: Int, val iconWidth: Float, val iconHeight: Float, val fontSize: Float, val tracking: Float) {
    Home("HOME", R.drawable.figma_tab_home, 20f, 20f, 10.8f, .24f),
    FitLab("FIT LAB", R.drawable.figma_tab_fit, 19f, 15f, 11.5f, -.8f),
    Closet("CLOSET", R.drawable.figma_tab_closet, 19.01f, 19f, 12f, -.8f),
}

@Composable
fun CoorditBottomNavigation(selectedTab: CoorditTab?, scale: Float, onTabSelection: (CoorditTab) -> Unit, modifier: Modifier = Modifier) {
    Box(modifier.fillMaxWidth().height((92 * scale).dp).padding(horizontal = (16 * scale).dp).padding(bottom = (10 * scale).dp),
        contentAlignment = Alignment.BottomCenter) {
        Row(Modifier.fillMaxWidth().height((66 * scale).dp)
            .coorditShadow(AppColors.ink.copy(alpha = .28f), (12 * scale).dp, CircleShape, (6 * scale).dp)
            // Native iOS glass brightens its backdrop before applying the navy tint.
            .background(AppColors.panel.copy(alpha = .9f), CircleShape)
            .background(AppColors.ink.copy(alpha = .42f), CircleShape)
            .border(.8.dp, Color.White.copy(alpha = .28f), CircleShape).padding((6 * scale).dp),
            horizontalArrangement = Arrangement.spacedBy((8 * scale).dp), verticalAlignment = Alignment.CenterVertically) {
            CoorditTab.entries.forEach { tab ->
                Pressable({ onTabSelection(tab) }, Modifier.weight(1f).heightIn(min = (50 * scale).dp)
                    .background(if (selectedTab == tab) Color.White.copy(alpha = .18f) else Color.Transparent, CircleShape)
                    .semantics { selected = selectedTab == tab; contentDescription = tab.title }, cornerRadius = 40 * scale) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy((3 * scale).dp)) {
                        Box(Modifier.height((20 * scale).dp), contentAlignment = Alignment.BottomCenter) {
                            Image(painterResource(tab.resource), null, Modifier.size((tab.iconWidth * scale).dp, (tab.iconHeight * scale).dp))
                        }
                        BasicText(tab.title, style = CoorditTypography.climate2010(tab.fontSize * scale)
                            .copy(color = AppColors.foreground, letterSpacing = (tab.tracking * scale).sp), maxLines = 1)
                    }
                }
            }
        }
    }
}

/** SwiftUI kerning includes the final glyph advance; Compose letterSpacing excludes it. */
@Composable
private fun KernedLogoText(text: AnnotatedString, style: TextStyle, modifier: Modifier) {
    val density = LocalDensity.current
    val measured = rememberTextMeasurer().measure(text, style, softWrap = false, maxLines = 1)
    val width = with(density) { measured.size.width.toDp() + style.letterSpacing.toDp() }
    BasicText(text, modifier.width(width).clipToBounds(), style = style, softWrap = false, maxLines = 1, overflow = TextOverflow.Visible)
}
