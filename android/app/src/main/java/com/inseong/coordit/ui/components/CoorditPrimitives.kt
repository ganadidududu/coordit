package com.inseong.coordit.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.inseong.coordit.ui.theme.*

@Composable
fun CoorditText(text: String, style: TextStyle, modifier: Modifier = Modifier) {
    BasicText(text = text, modifier = modifier, style = style)
}

@Composable
fun Pressable(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    cornerRadius: Float = 10f,
    content: @Composable BoxScope.() -> Unit,
) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale by animateFloatAsState(if (pressed && enabled) .965f else 1f, tween(35), label = "press scale")
    val alpha by animateFloatAsState(if (!enabled) .38f else if (pressed) .88f else 1f, tween(35), label = "press alpha")
    Box(modifier.graphicsLayer { scaleX = scale; scaleY = scale; this.alpha = alpha }
        .clip(RoundedCornerShape(cornerRadius.dp))
        .clickable(interactionSource = interaction, indication = null, enabled = enabled, role = Role.Button, onClick = onClick),
        contentAlignment = Alignment.Center) {
        content()
        if (pressed && enabled) Box(Modifier.matchParentSize().background(Color.Black.copy(alpha = .16f)))
    }
}

@Composable
fun CoorditButton(text: String, onClick: () -> Unit, modifier: Modifier = Modifier, secondary: Boolean = false,
    enabled: Boolean = true, height: Float = 48f, fontSize: Float = 13f, cornerRadius: Float = 7f) {
    Pressable(onClick, modifier, enabled, cornerRadius) {
        Box(Modifier.fillMaxWidth().heightIn(min = height.dp)
            .background(if (secondary) AppColors.placeholder else AppColors.ink).padding(horizontal = 12.dp, vertical = 12.dp),
            contentAlignment = Alignment.Center) {
            BasicText(text, style = CoorditTypography.gmarketBold(fontSize).copy(
                color = if (secondary) AppColors.ink else Color.White, textAlign = TextAlign.Center), maxLines = 2)
        }
    }
}

@Composable
fun BackTitleCard(title: String, scale: Float, onBack: () -> Unit, modifier: Modifier = Modifier) {
    val titleSize = if (title.length >= 6) 18f else 22f
    Pressable(onBack, modifier.semantics { contentDescription = "$title 뒤로가기" }, cornerRadius = 6 * scale) {
        Row(Modifier.width((372 * scale).dp).height((60 * scale).dp).background(AppColors.panel)
            .padding(horizontal = (26 * scale).dp), verticalAlignment = Alignment.CenterVertically) {
            Canvas(Modifier.size((23 * scale).dp)) {
                drawLine(Color.Black.copy(alpha = .82f), Offset(size.width * .65f, size.height * .12f),
                    Offset(size.width * .25f, size.height * .5f), 3 * scale * density, StrokeCap.Round)
                drawLine(Color.Black.copy(alpha = .82f), Offset(size.width * .25f, size.height * .5f),
                    Offset(size.width * .65f, size.height * .88f), 3 * scale * density, StrokeCap.Round)
            }
            Spacer(Modifier.width((15 * scale).dp))
            BasicText(title, style = CoorditTypography.climate2019(titleSize * scale).copy(color = Color.Black, letterSpacing = (1.2f * scale).sp), maxLines = 1)
        }
    }
}
