import SwiftUI

#if os(iOS)
struct CoorditFitLabScoreCard: View {
    let variant: CoorditFitLabResultVariant
    let metrics: CoorditResponsiveMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.value(7)) {
            Text(variant.scoreBasis)
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
                ForEach(variant.metrics) { metric in
                    CoorditFitLabMetricCell(metric: metric, metrics: metrics)
                }
            }

            Text("총점 |")
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
