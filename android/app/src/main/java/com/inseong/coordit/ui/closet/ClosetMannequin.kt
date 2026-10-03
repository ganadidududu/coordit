package com.inseong.coordit.ui.closet

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BlurMaskFilter
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RectF
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.inseong.coordit.R
import com.inseong.coordit.ui.components.CoorditText
import com.inseong.coordit.ui.theme.AppColors
import com.inseong.coordit.ui.theme.CoorditTypography
import java.text.DecimalFormat
import java.text.DecimalFormatSymbols
import java.util.Locale
import kotlin.math.abs
import kotlin.math.min
import kotlin.math.roundToInt

private data class Region(val x: Float,val y: Float,val w: Float,val h: Float)
private data class Measurement(val key: String,val title: String,val tolerance: Double,val body: Offset,val label: Offset,val regions: List<Region>)
// Normalized coordinates preserve CoorditFitLabComponents.swift:205–230,365–396.
private val upperMeasurements=listOf(
    Measurement("shoulder_width","어깨",.5,Offset(.40f,.30f),Offset(.23f,.22f),listOf(Region(.26f,.20f,.48f,.11f))),
    Measurement("chest_width","가슴",.75,Offset(.56f,.43f),Offset(.77f,.32f),listOf(Region(.27f,.32f,.16f,.18f),Region(.57f,.32f,.16f,.18f))),
    Measurement("total_length","총장",1.0,Offset(.43f,.60f),Offset(.23f,.55f),listOf(Region(.28f,.51f,.17f,.20f),Region(.55f,.51f,.17f,.20f))),
    Measurement("sleeve_length","소매",.75,Offset(.62f,.75f),Offset(.77f,.57f),listOf(Region(.14f,.31f,.17f,.47f),Region(.69f,.31f,.17f,.47f))),
)
private val lowerMeasurements=listOf(
    Measurement("waist_width","허리",.5,Offset(.445f,.24f),Offset(.23f,.23f),listOf(Region(.27f,.18f,.18f,.13f),Region(.55f,.18f,.18f,.13f))),
    Measurement("hip_width","힙",.75,Offset(.57f,.36f),Offset(.77f,.35f),listOf(Region(.23f,.29f,.20f,.16f),Region(.57f,.29f,.20f,.16f))),
    Measurement("rise","밑위",.5,Offset(.50f,.50f),Offset(.23f,.49f),listOf(Region(.42f,.37f,.16f,.23f))),
    Measurement("outseam","총장",1.0,Offset(.57f,.82f),Offset(.77f,.62f),listOf(Region(.22f,.42f,.20f,.50f),Region(.58f,.42f,.20f,.50f))),
)
private object MannequinVisualTokens {
    val neutralContour = Color(.53f, .57f, .64f, .48f)
    val panelBorder = Color.Black.copy(alpha = .12f)
    val legendBorder = Color.Black.copy(alpha = .18f)
    val calloutSurface = Color.White.copy(alpha = .96f)
}

private enum class Direction(val title:String,val color:Color,val contour:Color) {
    Tight("타이트",AppColors.red,ClosetDesign.tightContour),
    Similar("비슷",AppColors.green,AppColors.green),
    Loose("여유",AppColors.blue,ClosetDesign.looseContour),
}
private fun direction(value:Double,tolerance:Double)=when {
    abs(value)<=tolerance -> Direction.Similar
    value<0 -> Direction.Tight
    else -> Direction.Loose
}
private fun signed(value:Double):String {
    if(abs(value)<.001) return "0"
    val text=DecimalFormat("0.##",DecimalFormatSymbols(Locale.KOREA)).format(value)
    return if(value>0) "+$text" else text
}

@Composable
fun ClosetMannequin(upper:Boolean,differences:Map<String,Double?>,scale:Float) {
    val context=LocalContext.current
    val mask=remember(upper,context) { BitmapFactory.decodeResource(context.resources,if(upper)R.drawable.coordit_fit_upper_line_mask else R.drawable.coordit_fit_lower_line_mask) }
    val available=(if(upper)upperMeasurements else lowerMeasurements).mapNotNull { measurement ->
        differences[measurement.key]?.takeIf(Double::isFinite)?.let { measurement to it }
    }
    Column(horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy((9*scale).dp)) {
        Box(Modifier.fillMaxWidth().height((286*scale).dp).clip(RoundedCornerShape((4*scale).dp)).background(AppColors.panel)
            .border(1.dp,MannequinVisualTokens.panelBorder,RoundedCornerShape((4*scale).dp))
            .testTag(if(upper)"closet-mannequin-top" else "closet-mannequin-bottom")
            .semantics { contentDescription=if(upper)"상의 핏 마네킹" else "하의 핏 마네킹" }) {
            Box(Modifier.matchParentSize().drawWithCache {
                val bitmap=Bitmap.createBitmap(size.width.roundToInt().coerceAtLeast(1),size.height.roundToInt().coerceAtLeast(1),Bitmap.Config.ARGB_8888)
                val canvas=android.graphics.Canvas(bitmap)
                canvas.drawColor(MannequinVisualTokens.neutralContour.toArgb())
                val paint=Paint(Paint.ANTI_ALIAS_FLAG)
                // Software rendering retains soft semantic regions on devices without RenderEffect.
                paint.maskFilter=BlurMaskFilter(8.dp.toPx(),BlurMaskFilter.Blur.NORMAL)
                available.forEach { (measurement,value) ->
                    paint.color=direction(value,measurement.tolerance).contour.copy(alpha=(.76+min(abs(value)/5,1.0)*.08).toFloat()).toArgb()
                    val path=android.graphics.Path()
                    measurement.regions.forEach { r -> path.addRect(r.x*size.width,r.y*size.height,(r.x+r.w)*size.width,(r.y+r.h)*size.height,android.graphics.Path.Direction.CW) }
                    canvas.drawPath(path,paint)
                }
                paint.maskFilter=null
                paint.xfermode=PorterDuffXfermode(PorterDuff.Mode.DST_IN)
                paint.color=android.graphics.Color.WHITE
                val inset=(7*scale).dp.toPx()
                val factor=min((size.width-inset*2)/mask.width,(size.height-inset*2)/mask.height).coerceAtLeast(0f)
                val w=mask.width*factor
                val h=mask.height*factor
                val fitted=Bitmap.createBitmap(bitmap.width,bitmap.height,Bitmap.Config.ARGB_8888)
                android.graphics.Canvas(fitted).drawBitmap(mask,null,RectF((size.width-w)/2,(size.height-h)/2,(size.width+w)/2,(size.height+h)/2),Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG))
                canvas.drawBitmap(fitted,0f,0f,paint)
                fitted.recycle()
                val image=bitmap.asImageBitmap()
                onDrawBehind { drawImage(image) }
            })
            Canvas(Modifier.matchParentSize()) {
                available.forEach { (measurement,value) ->
                    val color=direction(value,measurement.tolerance).color
                    val start=Offset(size.width*measurement.body.x,size.height*measurement.body.y)
                    val end=Offset(size.width*measurement.label.x,size.height*measurement.label.y)
                    val connector=Path().apply { moveTo(start.x,start.y);lineTo((start.x+end.x)/2,start.y);lineTo(end.x,end.y) }
                    drawPath(connector,color.copy(alpha=.72f),style=Stroke(1.25.dp.toPx(),cap=StrokeCap.Round,join=StrokeJoin.Round))
                    drawCircle(color,2.dp.toPx(),start)
                }
            }
            Layout(modifier=Modifier.matchParentSize(),content={ available.forEach { (measurement,value) -> Callout(measurement,value,scale) } }) { measurables,constraints ->
                val labels=measurables.map { it.measure(constraints.copy(minWidth=0,minHeight=0)) }
                layout(constraints.maxWidth,constraints.maxHeight) {
                    labels.forEachIndexed { index,label ->
                        val anchor=available[index].first.label
                        label.place((constraints.maxWidth*anchor.x-label.width/2).roundToInt(),(constraints.maxHeight*anchor.y-label.height/2).roundToInt())
                    }
                }
            }
        }
        Row(horizontalArrangement=Arrangement.spacedBy((7*scale).dp),modifier=Modifier.semantics(mergeDescendants=true) { contentDescription="마네킹 표시 범례. 빨간색 타이트, 초록색 비슷, 파란색 여유" }) {
            Direction.entries.forEach { direction ->
                Row(Modifier.border(1.dp,MannequinVisualTokens.legendBorder,CircleShape).padding(horizontal=4.dp,vertical=2.dp),verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(3.dp)) {
                    Box(Modifier.size((16*scale).dp,(4*scale).dp).background(direction.color,CircleShape))
                    CoorditText(direction.title,CoorditTypography.gmarketMedium(7*scale).copy(color=Color.Black))
                }
            }
        }
    }
}

@Composable
private fun Callout(measurement:Measurement,value:Double,scale:Float) {
    val direction=direction(value,measurement.tolerance)
    val shape=RoundedCornerShape((6*scale).dp)
    Column(Modifier.shadow((5*scale).dp,shape,ambientColor=direction.color.copy(alpha=.16f),spotColor=direction.color.copy(alpha=.28f))
        .background(MannequinVisualTokens.calloutSurface,shape).border(1.dp,direction.color.copy(alpha=.55f),shape)
        .padding(horizontal=(7*scale).dp,vertical=(5*scale).dp).testTag("closet-overlay-${measurement.key}")
        .semantics(mergeDescendants=true) { contentDescription="${measurement.title} ${direction.title}, 차이 ${signed(value)} cm" },verticalArrangement=Arrangement.spacedBy((1*scale).dp)) {
        Row(verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy((3*scale).dp)) {
            Box(Modifier.size((6*scale).dp).background(direction.color,CircleShape))
            CoorditText(measurement.title,CoorditTypography.gmarketBold(8*scale).copy(color=Color.Black))
        }
        CoorditText("${signed(value)} cm · ${direction.title}",CoorditTypography.gmarketBold(ClosetDesign.captionFont*scale).copy(color=direction.color))
    }
}
