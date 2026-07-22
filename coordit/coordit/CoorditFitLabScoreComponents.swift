import SwiftUI

#if os(iOS)
struct CoorditFitLabScoreCard: View {
    let variant: CoorditFitLabResultVariant
    let recommendation: CoorditFitRecommendation?
    let metrics: CoorditResponsiveMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.value(7)) {
            Text(recommendation.map { "추천 사이즈 \( $0.recommendedSize ) 기준" } ?? variant.scoreBasis)
                .font(CoorditTypography.mona12(size: metrics.value(10), relativeTo: .caption))
                .foregroundStyle(CoorditFitLabPalette.muted)
            Text("FIT SCORE")
                .font(CoorditTypography.climate2019(size: metrics.value(19), relativeTo: .headline))
                .tracking(metrics.value(0.7))
                .foregroundStyle(CoorditFitLabPalette.ink)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: metrics.value(8)),
                    GridItem(.flexible(), spacing: metrics.value(8))
                ],
                spacing: metrics.value(8)
            ) {
                ForEach(recommendation?.fitLabMetrics ?? variant.metrics) { metric in
                    CoorditFitLabMetricCell(metric: metric, metrics: metrics)
                }
            }

            Text("총점 | \(recommendation?.roundedFitScore ?? variant.defaultScore)")
                .font(CoorditTypography.gmarketBold(size: metrics.value(15), relativeTo: .body))
                .foregroundStyle(.white)
                .padding(.horizontal, metrics.value(17))
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: metrics.value(34))
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 50 / 255, green: 70 / 255, blue: 151 / 255),
                            CoorditFitLabPalette.ink
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: metrics.value(6)))
                .shadow(color: CoorditFitLabPalette.ink.opacity(0.28), radius: metrics.value(5), y: metrics.value(2))
        }
        .padding(.horizontal, metrics.value(12))
        .padding(.vertical, metrics.value(16))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CoorditFitLabPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: metrics.value(7)))
    }
}

private extension CoorditFitRecommendation {
    var roundedFitScore: Int {
        Int(fitScore.rounded())
    }

    var fitLabMetrics: [CoorditFitLabMetric] {
        [
            CoorditFitLabMetric(id: "shoulder", value: diff.shoulderWidth.coorditSignedCentimeters, label: "어깨"),
            CoorditFitLabMetric(id: "chest", value: diff.chestWidth.coorditSignedCentimeters, label: "가슴"),
            CoorditFitLabMetric(id: "length", value: (diff.totalLength ?? diff.outseam).coorditSignedCentimeters, label: diff.totalLength == nil ? "아웃심" : "총장"),
            CoorditFitLabMetric(id: "sleeve", value: (diff.sleeveLength ?? diff.rise).coorditSignedCentimeters, label: diff.sleeveLength == nil ? "밑위" : "소매")
        ]
    }
}

private extension Optional where Wrapped == Double {
    var coorditSignedCentimeters: String {
        guard let value = self else { return "- cm" }
        let sign = value > 0 ? "+" : ""
        let rounded = (value * 10).rounded() / 10
        if rounded.rounded() == rounded {
            return "\(sign)\(Int(rounded)) cm"
        }
        return "\(sign)\(rounded) cm"
    }
}

private struct CoorditFitLabMetricCell: View {
    let metric: CoorditFitLabMetric
    let metrics: CoorditResponsiveMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.value(1)) {
            Text(metric.value)
                .font(CoorditTypography.gmarketBold(size: metrics.value(15), relativeTo: .headline))
                .foregroundStyle(CoorditFitLabPalette.ink)
            Text(metric.label)
                .font(CoorditTypography.gmarketMedium(size: metrics.value(7), relativeTo: .caption2))
                .foregroundStyle(CoorditFitLabPalette.muted)
        }
        .padding(.leading, metrics.value(9))
        .frame(height: metrics.value(39), alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CoorditFitLabPalette.field)
        .clipShape(RoundedRectangle(cornerRadius: metrics.value(6)))
    }
}
#endif
