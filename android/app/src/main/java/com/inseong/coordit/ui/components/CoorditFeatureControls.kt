package com.inseong.coordit.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.inseong.coordit.ui.theme.*

enum class InputGlyph { Link, SizeChart, Camera, Ruler, Garment, Person, Care, SizeDifference, Circle, CheckCircle, CheckCircleFilled, CloseCircleFilled }

@Composable
fun InputMethodGlyph(glyph: InputGlyph, scale: Float, color: Color = AppColors.ink) {
    Canvas(Modifier.size((25 * scale).dp)) {
        val stroke = Stroke((2 * scale.coerceAtMost(1f)).dp.toPx(), cap = StrokeCap.Round)
        when (glyph) {
            InputGlyph.Link -> rotate(-35f) {
                drawRoundRect(color, Offset(size.width * .02f, size.height * .29f), Size(size.width * .6f, size.height * .4f), CornerRadius(size.height * .2f), style = stroke)
                drawRoundRect(color, Offset(size.width * .38f, size.height * .29f), Size(size.width * .6f, size.height * .4f), CornerRadius(size.height * .2f), style = stroke)
            }
            InputGlyph.SizeChart -> {
                listOf(Offset(0f, 0f), Offset(size.width, 0f), Offset(0f, size.height), Offset(size.width, size.height)).forEach { corner ->
                    val dx = if (corner.x == 0f) size.width * .28f else -size.width * .28f
                    val dy = if (corner.y == 0f) size.height * .28f else -size.height * .28f
                    drawLine(color, corner, corner + Offset(dx, 0f), stroke.width, StrokeCap.Round)
                    drawLine(color, corner, corner + Offset(0f, dy), stroke.width, StrokeCap.Round)
                }
            }
            InputGlyph.Camera -> {
                drawRoundRect(color, Offset(0f, size.height * .22f), Size(size.width, size.height * .65f), CornerRadius(size.width * .1f), style = stroke)
                drawCircle(color, size.width * .2f, center = Offset(size.width * .5f, size.height * .54f), style = stroke)
                drawLine(color, Offset(size.width * .3f, size.height * .12f), Offset(size.width * .65f, size.height * .12f), stroke.width, StrokeCap.Round)
            }
            InputGlyph.Ruler -> {
                drawRoundRect(color, cornerRadius = CornerRadius(size.width * .1f), style = stroke)
                (1..4).forEach { index -> drawLine(color, Offset(size.width * index / 5, 0f), Offset(size.width * index / 5, size.height * .35f), stroke.width) }
            }
            InputGlyph.Garment -> {
                val garment = androidx.compose.ui.graphics.Path().apply {
                    moveTo(size.width * .3f, size.height * .08f)
                    lineTo(size.width * .05f, size.height * .22f); lineTo(size.width * .15f, size.height * .45f)
                    lineTo(size.width * .28f, size.height * .38f); lineTo(size.width * .28f, size.height * .92f)
                    lineTo(size.width * .72f, size.height * .92f); lineTo(size.width * .72f, size.height * .38f)
                    lineTo(size.width * .85f, size.height * .45f); lineTo(size.width * .95f, size.height * .22f)
                    lineTo(size.width * .7f, size.height * .08f)
                    quadraticTo(size.width * .5f, size.height * .35f, size.width * .3f, size.height * .08f)
                    close()
                }
                drawPath(garment, color, style = stroke)
            }
            InputGlyph.Person -> {
                drawCircle(color, size.width * .17f, Offset(size.width * .5f, size.height * .22f), style = stroke)
                drawRoundRect(color, Offset(size.width * .15f, size.height * .55f), Size(size.width * .7f, size.height * .35f), CornerRadius(size.width * .2f), style = stroke)
            }
            InputGlyph.Care -> {
                val drop = androidx.compose.ui.graphics.Path().apply {
                    moveTo(size.width * .5f, size.height * .05f)
                    cubicTo(size.width * .2f, size.height * .45f, size.width * .05f, size.height * .7f, size.width * .25f, size.height * .88f)
                    cubicTo(size.width * .4f, size.height * 1.03f, size.width * .75f, size.height * .98f, size.width * .8f, size.height * .7f)
                    cubicTo(size.width * .82f, size.height * .5f, size.width * .62f, size.height * .22f, size.width * .5f, size.height * .05f)
                    close()
                }
                drawPath(drop, color, style = stroke)
            }
            InputGlyph.SizeDifference -> {
                listOf(.32f to false, .68f to true).forEach { (y, reversed) ->
                    val start = Offset(size.width * .08f, size.height * y)
                    val end = Offset(size.width * .92f, size.height * y)
                    drawLine(color, start, end, stroke.width, StrokeCap.Round)
                    val tip = if (reversed) start else end
                    val dx = size.width * if (reversed) .22f else -.22f
                    drawLine(color, tip, tip + Offset(dx, -size.height * .2f), stroke.width, StrokeCap.Round)
                    drawLine(color, tip, tip + Offset(dx, size.height * .2f), stroke.width, StrokeCap.Round)
                }
            }
            InputGlyph.Circle, InputGlyph.CheckCircle, InputGlyph.CheckCircleFilled, InputGlyph.CloseCircleFilled -> {
                val filled = glyph == InputGlyph.CheckCircleFilled || glyph == InputGlyph.CloseCircleFilled
                val radius = size.minDimension * .44f
                if (filled) drawCircle(color, radius) else drawCircle(color, radius, style = stroke)
                val mark = if (filled) AppColors.panel else color
                if (glyph == InputGlyph.CloseCircleFilled) {
                    drawLine(mark, Offset(size.width * .34f, size.height * .34f), Offset(size.width * .66f, size.height * .66f), stroke.width, StrokeCap.Round)
                    drawLine(mark, Offset(size.width * .66f, size.height * .34f), Offset(size.width * .34f, size.height * .66f), stroke.width, StrokeCap.Round)
                } else if (glyph != InputGlyph.Circle) {
                    drawLine(mark, Offset(size.width * .27f, size.height * .5f), Offset(size.width * .44f, size.height * .66f), stroke.width, StrokeCap.Round)
                    drawLine(mark, Offset(size.width * .44f, size.height * .66f), Offset(size.width * .74f, size.height * .35f), stroke.width, StrokeCap.Round)
                }
            }
        }
    }
}

@Composable
fun FeatureTitleBar(title: String, scale: Float, onBack: () -> Unit, onHelp: () -> Unit, backTag: String, helpTag: String) {
    Row(Modifier.fillMaxWidth().padding(horizontal = (16 * scale).dp)
        .background(AppColors.panel, RoundedCornerShape((7 * scale).dp)), verticalAlignment = Alignment.CenterVertically) {
        Pressable(onBack, Modifier.weight(1f).heightIn(min = (60 * scale).dp).testTag(backTag)
            .semantics { contentDescription = "$title 뒤로가기" }, cornerRadius = 7 * scale) {
            Row(Modifier.fillMaxWidth().padding(start = (29 * scale).dp), verticalAlignment = Alignment.CenterVertically) {
                Canvas(Modifier.size((25 * scale).dp)) {
                    drawLine(AppColors.ink, Offset(size.width * .65f, size.height * .12f), Offset(size.width * .25f, size.height * .5f), 3.dp.toPx(), StrokeCap.Round)
                    drawLine(AppColors.ink, Offset(size.width * .25f, size.height * .5f), Offset(size.width * .65f, size.height * .88f), 3.dp.toPx(), StrokeCap.Round)
                }
                Spacer(Modifier.width((18 * scale).dp))
                CoorditText(title, CoorditTypography.gmarketBold(22 * scale).copy(color = androidx.compose.ui.graphics.Color.Black, letterSpacing = (1.5f * scale).sp))
            }
        }
        Pressable(onHelp, Modifier.heightIn(min = 44.dp).background(AppColors.closetField, RoundedCornerShape(24.dp)).padding(horizontal = (12 * scale).dp).testTag(helpTag).semantics { contentDescription = "$title 사용법" }, cornerRadius = 24f) {
            CoorditText("ⓘ  사용법", CoorditTypography.gmarketMedium(11 * scale))
        }
        Spacer(Modifier.width((9 * scale).dp))
    }
}

@Composable
fun LinkPasteButton(scale: Float, tag: String, enabled: Boolean = true, onPaste: (String) -> Unit) {
    val clipboard = LocalClipboardManager.current
    CoorditButton("붙여넣기", { clipboard.getText()?.text?.let(onPaste) }, Modifier.testTag(tag), secondary = true,
        enabled = enabled, height = 44 * scale, fontSize = 11 * scale)
}

@Composable
fun CameraComingSoon(onDismiss: () -> Unit) {
    androidx.compose.ui.window.Dialog(onDismissRequest = onDismiss) {
        Column(Modifier.fillMaxWidth().background(AppColors.panel, RoundedCornerShape(14.dp)).padding(24.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
            CoorditText("카메라 측정 기능은 준비 중입니다!", CoorditTypography.gmarketBold(18f))
            CoorditButton("확인", onDismiss, Modifier.testTag("camera-coming-soon-close"))
        }
    }
}

@Composable
fun CoorditConfirmationDialog(title: String, message: String, cancelTitle: String, confirmTitle: String, cancel: () -> Unit, confirm: () -> Unit, tag: String, destructive: Boolean = false) {
    androidx.compose.ui.window.Dialog(onDismissRequest = cancel) {
        Column(Modifier.fillMaxWidth().background(AppColors.panel, RoundedCornerShape(14.dp)).padding(24.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            CoorditText(title, CoorditTypography.gmarketBold(18f))
            CoorditText(message, CoorditTypography.gmarketMedium(13f))
            CoorditButton(cancelTitle, cancel, Modifier.testTag("$tag-cancel"))
            CoorditButton(confirmTitle, confirm, Modifier.testTag(tag), secondary = !destructive, danger = destructive)
        }
    }
}
