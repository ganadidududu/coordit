package com.inseong.coordit.ui.components

import android.provider.Settings
import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import com.inseong.coordit.R
import com.inseong.coordit.ui.theme.AppColors
import kotlin.math.cos
import kotlin.math.sin

@Composable
fun OrbitLoadingIndicator(scale: Float, active: Boolean, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val reduceMotion = Settings.Global.getFloat(context.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f
    val phase = if (active && !reduceMotion) {
        val transition = rememberInfiniteTransition(label = "loading-orbit")
        val angle by transition.animateFloat(0f, (Math.PI * 2).toFloat(), infiniteRepeatable(tween(1800, easing = LinearEasing)), label = "loading-sparkle")
        angle
    } else 0f
    Box(modifier.size((92 * scale).dp), contentAlignment = Alignment.Center) {
        Image(painterResource(R.drawable.coordit_loading_mannequin), null, Modifier.size((58 * scale).dp, (82 * scale).dp), colorFilter = ColorFilter.tint(AppColors.muted.copy(alpha = .52f)))
        Canvas(Modifier.fillMaxSize()) {
            val x = cos(phase) * 41 * scale.dp.toPx()
            val y = sin(phase) * 19 * scale.dp.toPx()
            val tilt = Math.toRadians(-24.0).toFloat()
            rotate(-24f) {
                drawOval(AppColors.ink.copy(alpha = .3f), Offset(center.x - 41 * scale.dp.toPx(), center.y - 19 * scale.dp.toPx()), Size(82 * scale.dp.toPx(), 38 * scale.dp.toPx()), style = Stroke(1.5f * scale.dp.toPx()))
            }
            val sparkle = center + Offset(x * cos(tilt) - y * sin(tilt), x * sin(tilt) + y * cos(tilt))
            val radius = 5 * scale.dp.toPx()
            val path = Path().apply {
                moveTo(sparkle.x, sparkle.y - radius)
                quadraticTo(sparkle.x, sparkle.y, sparkle.x + radius, sparkle.y)
                quadraticTo(sparkle.x, sparkle.y, sparkle.x, sparkle.y + radius)
                quadraticTo(sparkle.x, sparkle.y, sparkle.x - radius, sparkle.y)
                quadraticTo(sparkle.x, sparkle.y, sparkle.x, sparkle.y - radius)
                close()
            }
            drawPath(path, AppColors.loadingSparkle)
        }
    }
}
