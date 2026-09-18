package com.inseong.coordit.ui.components

import android.graphics.Bitmap
import android.graphics.BlurMaskFilter
import android.graphics.Canvas
import android.graphics.Paint
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.asAndroidPath
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.unit.Dp
import kotlin.math.ceil

/** Software mask preserves explicit SwiftUI blur/offset geometry on API 26+. */
fun Modifier.coorditShadow(color: Color, radius: Dp, shape: Shape, offsetY: Dp): Modifier = drawWithCache {
    val sigma = radius.toPx()
    val padding = ceil(sigma * 3f).toInt()
    val bitmap = Bitmap.createBitmap(
        ceil(size.width).toInt().coerceAtLeast(1) + padding * 2,
        ceil(size.height).toInt().coerceAtLeast(1) + padding * 2,
        Bitmap.Config.ARGB_8888,
    )
    val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        this.color = color.toArgb()
        // Android's blur radius converts to sigma as radius * 0.57735 + 0.5.
        if (sigma > 0.5f) maskFilter = BlurMaskFilter((sigma - 0.5f) / 0.57735f, BlurMaskFilter.Blur.NORMAL)
    }
    val canvas = Canvas(bitmap)
    canvas.translate(padding.toFloat(), padding.toFloat())
    val outline = shape.createOutline(size, layoutDirection, this)
    when (outline) {
        is Outline.Generic -> canvas.drawPath(outline.path.asAndroidPath(), paint)
        is Outline.Rectangle -> canvas.drawRect(0f, 0f, size.width, size.height, paint)
        is Outline.Rounded -> {
            val path = androidx.compose.ui.graphics.Path().apply { addRoundRect(outline.roundRect) }
            canvas.drawPath(path.asAndroidPath(), paint)
        }
    }
    val shadow = bitmap.asImageBitmap()
    onDrawBehind { drawImage(shadow, topLeft = Offset(-padding.toFloat(), -padding + offsetY.toPx())) }
}
