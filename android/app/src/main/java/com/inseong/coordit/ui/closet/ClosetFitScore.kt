package com.inseong.coordit.ui.closet

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.unit.dp
import com.inseong.coordit.data.closet.ClosetComparison
import com.inseong.coordit.ui.components.CoorditText
import com.inseong.coordit.ui.theme.AppColors
import com.inseong.coordit.ui.theme.CoorditTypography
import java.text.DecimalFormat
import java.text.DecimalFormatSymbols
import java.util.Locale

// CoorditClosetDetailScreen.swift:228–314 and CoorditClosetComponents.swift:77–116.
private object FitScoreDesign {
    const val gap = 8f
    const val inset = 11f
    const val radius = 8f
    const val eyebrowSize = 10f
    const val headingSize = 22f
    const val explanationSize = 11f
    const val tileHeight = 51f
    const val tileInset = 9f
    const val tileGap = 3f
    const val valueSize = 16f
    const val labelSize = 8f
    const val totalHeight = 38f
    const val totalRadius = 7f
    const val totalSize = 17f
    const val eyebrowAlpha = .42f
    const val explanationAlpha = .70f
    const val unavailableAlpha = .62f
    const val labelAlpha = .46f
}

@Composable
fun ClosetFitScore(comparison: ClosetComparison?, upper: Boolean, scale: Float) {
    val score = comparison?.fitScore?.takeIf(Double::isFinite)
    val gap = comparison?.bestFitGap?.takeIf(Double::isFinite)
    Column(
        Modifier.fillMaxWidth().background(AppColors.panel, RoundedCornerShape((FitScoreDesign.radius * scale).dp))
            .padding((FitScoreDesign.inset * scale).dp).testTag("closet-detail-fit-score"),
        verticalArrangement = Arrangement.spacedBy((FitScoreDesign.gap * scale).dp),
    ) {
        CoorditText("BEST FIT 비교", CoorditTypography.gmarketMedium(FitScoreDesign.eyebrowSize * scale).copy(color = AppColors.ink.copy(alpha = FitScoreDesign.eyebrowAlpha)))
        CoorditText("FIT SCORE", CoorditTypography.climate2019(FitScoreDesign.headingSize * scale))
        if (score != null && gap != null) {
            CoorditText("BEST FIT과 ${formatScore(gap)}점 차이", CoorditTypography.gmarketMedium(FitScoreDesign.explanationSize * scale).copy(color = AppColors.ink.copy(alpha = FitScoreDesign.explanationAlpha)), Modifier.testTag("closet-detail-best-fit-gap"))
            val measurements = if (upper) listOf("shoulder_width" to "어깨", "chest_width" to "가슴", "total_length" to "총장", "sleeve_length" to "소매")
                else listOf("waist_width" to "허리", "hip_width" to "엉덩이", "rise" to "밑위", "outseam" to "총장")
            Column(verticalArrangement = Arrangement.spacedBy((FitScoreDesign.gap * scale).dp)) {
                measurements.chunked(2).forEachIndexed { rowIndex, row ->
                    Row(horizontalArrangement = Arrangement.spacedBy((FitScoreDesign.gap * scale).dp)) {
                        row.forEachIndexed { columnIndex, (key, label) ->
                            FitDifferenceTile(label, comparison.diff?.get(key), rowIndex * 2 + columnIndex, scale, Modifier.weight(1f))
                        }
                    }
                }
            }
            Box(
                Modifier.fillMaxWidth().height((FitScoreDesign.totalHeight * scale).dp)
                    .background(AppColors.ink, RoundedCornerShape((FitScoreDesign.totalRadius * scale).dp))
                    .testTag("closet-detail-total-score"),
                contentAlignment = Alignment.Center,
            ) {
                CoorditText("총점 | ${formatScore(score)}", CoorditTypography.gmarketBold(FitScoreDesign.totalSize * scale).copy(color = Color.White))
            }
        } else {
            CoorditText(
                if (comparison == null) "핏 비교 결과를 불러오지 못했어요." else "BEST FIT 기준 의류를 선택하면 점수와 차이가 보여요.",
                CoorditTypography.gmarketMedium(FitScoreDesign.explanationSize * scale).copy(color = AppColors.ink.copy(alpha = FitScoreDesign.unavailableAlpha)),
                Modifier.testTag("closet-detail-fit-comparison-unavailable"),
            )
        }
    }
}

@Composable
private fun FitDifferenceTile(label: String, difference: Double?, index: Int, scale: Float, modifier: Modifier) {
    val value = difference?.takeIf(Double::isFinite)?.let {
        val number = DecimalFormat("0.#", DecimalFormatSymbols(Locale.KOREA)).format(it)
        "${if (it > 0) "+" else ""}$number cm"
    } ?: "—"
    Column(
        modifier.height((FitScoreDesign.tileHeight * scale).dp)
            .background(AppColors.closetField, RoundedCornerShape((FitScoreDesign.radius * scale).dp))
            .padding(horizontal = (FitScoreDesign.tileInset * scale).dp)
            .testTag("closet-detail-fit-difference-$index")
            .clearAndSetSemantics { contentDescription = "$label, $value" },
        verticalArrangement = Arrangement.spacedBy((FitScoreDesign.tileGap * scale).dp, Alignment.CenterVertically),
    ) {
        CoorditText(value, CoorditTypography.gmarketBold(FitScoreDesign.valueSize * scale))
        CoorditText(label, CoorditTypography.gmarketMedium(FitScoreDesign.labelSize * scale).copy(color = AppColors.ink.copy(alpha = FitScoreDesign.labelAlpha)))
    }
}

private fun formatScore(value: Double): String = DecimalFormat("0.0", DecimalFormatSymbols(Locale.KOREA)).format(value)
