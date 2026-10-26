package com.inseong.coordit.data.fitlab

data class FitLabScoreSelection(
    val sizeLabel: String,
    val fitScore: Double,
    val isRecommended: Boolean,
    val comparisons: List<FitLabComparison>,
    val fitPointScores: List<FitLabFitPointScore>,
    val measurementScores: List<FitLabMeasurementScore>,
)

fun selectFitLabScore(
    recommendation: FitLabRecommendation,
    report: FitLabReportResponse?,
    sizeLabel: String,
): FitLabScoreSelection {
    val recommended = sizeLabel == recommendation.recommendedSize
    val row = recommendation.allSizeScores.firstOrNull { it.sizeLabel == sizeLabel }
    val labels = mapOf(
        "shoulder_width" to "어깨", "chest_width" to "가슴", "sleeve_length" to "소매",
        "total_length" to "총장", "waist_width" to "허리", "hip_width" to "힙",
        "rise" to "밑위", "outseam" to "총장",
    )
    val comparisons = if (recommended) report?.chartData?.idealVsProduct.orEmpty() else row?.semanticFacts.orEmpty()
        .filter { it.measurement in labels && it.reference.isFinite() && it.product.isFinite() && it.diff.isFinite() }
        .map { FitLabComparison(it.measurement, labels.getValue(it.measurement), it.reference, it.product, it.diff, null) }
    val points = if (recommended) report?.chartData?.fitPointScores.orEmpty() else
        listOf("silhouette" to "실루엣", "mobility" to "활동성", "layering" to "레이어링").mapNotNull { (key, label) ->
            row?.semanticSubscores?.get(key)?.takeIf { it.isFinite() && it in 0.0..100.0 }
                ?.let { FitLabFitPointScore(key, label, it) }
        }
    val measurements = if (recommended) report?.chartData?.measurementScores.orEmpty() else comparisons.mapNotNull { comparison ->
        row?.measurementSubscores?.get(comparison.measurement)?.takeIf { it.isFinite() && it in 0.0..100.0 }
            ?.let { FitLabMeasurementScore(comparison.measurement, comparison.label, it, comparison.diff, comparison.status) }
    }
    return FitLabScoreSelection(sizeLabel, row?.fitScore ?: if (recommended) recommendation.fitScore else
        report?.chartData?.sizeScoreRanking?.firstOrNull { it.sizeLabel == sizeLabel }?.fitScore ?: Double.NaN,
        recommended, comparisons, points, measurements)
}
