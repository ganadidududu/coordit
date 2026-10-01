package com.inseong.coordit.ui.components

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection

/** Control points extracted from SwiftUI RoundedRectangle(style: .continuous).path(in:). */
class ContinuousRoundedShape(private val radius: Dp) : Shape {
    override fun createOutline(size: Size, layoutDirection: LayoutDirection, density: Density): Outline {
        val r = with(density) { radius.toPx() }.coerceAtMost(minOf(size.width, size.height) / 3.0573299f)
        val extent = 1.52866495f
        val path = Path()
        val corners: List<(Float, Float) -> Offset> = listOf(
            { x, y -> Offset(size.width - y * r, x * r) },
            { x, y -> Offset(size.width - x * r, size.height - y * r) },
            { x, y -> Offset(y * r, size.height - x * r) },
            { x, y -> Offset(x * r, y * r) },
        )
        corners.forEachIndexed { index, point ->
            val start = point(0f, extent)
            if (index == 0) path.moveTo(start.x, start.y) else path.lineTo(start.x, start.y)
            fun curve(x1: Float, y1: Float, x2: Float, y2: Float, x3: Float, y3: Float) {
                val a = point(x1, y1); val b = point(x2, y2); val c = point(x3, y3)
                path.cubicTo(a.x, a.y, b.x, b.y, c.x, c.y)
            }
            curve(0f, 1.08849001f, 0f, 0.86840701f, 0.0749114f, 0.63149399f)
            curve(0.16906001f, 0.37282401f, 0.37282401f, 0.16906001f, 0.63149399f, 0.0749114f)
            curve(0.86840701f, 0f, 1.08849001f, 0f, extent, 0f)
        }
        path.close()
        return Outline.Generic(path)
    }
}
