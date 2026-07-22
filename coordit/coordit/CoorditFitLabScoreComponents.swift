import SwiftUI

#if os(iOS)
struct CoorditFitLabResultMeasurement: Identifiable {
    enum Direction {
        case tight
        case similar
        case loose

        var label: String {
            switch self {
            case .tight: "타이트"
            case .similar: "비슷"
            case .loose: "여유"
            }
        }

        var glyph: String {
            switch self {
            case .tight: "−"
            case .similar: "≈"
            case .loose: "+"
            }
        }
    }

    let key: CoorditFitLabMeasurementKey
    let title: String
    let comparison: CoorditFitLabReportResponse.ChartData.Comparison?

    var id: String { key.rawValue }

    var direction: Direction? {
        guard let comparison, comparison.diff.isFinite else { return nil }
        switch comparison.status?.lowercased() {
        case "tight", "small", "타이트": return .tight
        case "similar", "same", "비슷": return .similar
        case "loose", "large", "여유": return .loose
        default:
            if abs(comparison.diff) < 0.001 { return .similar }
            return comparison.diff < 0 ? .tight : .loose
        }
    }

    var accessibilityValue: String {
        guard let comparison,
              comparison.ideal.isFinite,
              comparison.product.isFinite,
              comparison.diff.isFinite,
              let direction
        else { return "비교 데이터 없음" }
        return "베스트 \(Self.number(comparison.ideal)) cm | 상품 \(Self.number(comparison.product)) cm | 차이 \(Self.signed(comparison.diff)) cm | \(direction.label)"
    }

    static func number(_ value: Double) -> String {
        guard value.isFinite else { return "-" }
        if value == value.rounded() { return String(Int(value)) }
        return value.formatted(.number.precision(.fractionLength(0...2)))
    }

    static func signed(_ value: Double) -> String {
        guard value.isFinite else { return "-" }
        if abs(value) < 0.001 { return "0" }
        return "\(value > 0 ? "+" : "")\(number(value))"
    }
}

struct CoorditFitLabScoreCard: View {
    let variant: CoorditFitLabResultVariant
    let recommendation: CoorditFitLabRecommendationResponse?
    let report: CoorditFitLabReportResponse?
    let metrics: CoorditResponsiveMetrics

    init(
        variant: CoorditFitLabResultVariant,
        recommendation: CoorditFitLabRecommendationResponse? = nil,
        report: CoorditFitLabReportResponse? = nil,
        metrics: CoorditResponsiveMetrics
    ) {
        self.variant = variant
        self.recommendation = recommendation
        self.report = report
        self.metrics = metrics
    }

    var measurements: [CoorditFitLabResultMeasurement] {
        variant.measurementKeys.map { key in
            CoorditFitLabResultMeasurement(
                key: key,
                title: variant.label(for: key),
                comparison: report?.chartData.idealVsProduct.first { $0.measurement == key }
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.value(10)) {
            Text(variant.scoreBasis)
                .font(CoorditTypography.mona12(size: metrics.value(10), relativeTo: .caption))
                .foregroundStyle(Color.black.opacity(0.64))
            Text("FIT SCORE")
                .font(CoorditTypography.climate2019(size: metrics.value(19), relativeTo: .headline))
                .tracking(metrics.value(0.7))
                .foregroundStyle(Color.black)

            HStack(alignment: .firstTextBaseline, spacing: metrics.value(7)) {
                VStack(alignment: .leading, spacing: metrics.value(2)) {
                    Text("추천 사이즈")
                        .font(CoorditTypography.gmarketMedium(size: metrics.value(9), relativeTo: .caption))
                    Text(recommendation?.recommendedSize ?? "-")
                        .font(CoorditTypography.gmarketBold(size: metrics.value(20), relativeTo: .title3))
                        .accessibilityIdentifier("fitlab-recommended-size")
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: metrics.value(2)) {
                    Text("총점")
                        .font(CoorditTypography.gmarketMedium(size: metrics.value(9), relativeTo: .caption))
                    Text(scoreText)
                        .font(CoorditTypography.gmarketBold(size: metrics.value(20), relativeTo: .title3))
                        .accessibilityIdentifier("fitlab-total-score")
                }
            }
            .foregroundStyle(Color.black)
        }
        .padding(metrics.value(14))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CoorditFitLabPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: metrics.value(7)))
        .overlay(
            RoundedRectangle(cornerRadius: metrics.value(7))
                .stroke(Color.black.opacity(0.12), lineWidth: 1)
        )
    }

    private var scoreText: String {
        guard let score = recommendation?.fitScore, score.isFinite else { return "-" }
        return CoorditFitLabResultMeasurement.number(score)
    }
}

struct CoorditFitLabMeasurementRows: View {
    let measurements: [CoorditFitLabResultMeasurement]
    let metrics: CoorditResponsiveMetrics

    var body: some View {
        VStack(spacing: metrics.value(7)) {
            ForEach(measurements) { measurement in
                HStack(spacing: metrics.value(8)) {
                    Text(measurement.title)
                        .font(CoorditTypography.gmarketBold(size: metrics.value(12), relativeTo: .body))
                        .frame(width: metrics.value(42), alignment: .leading)
                    if let comparison = measurement.comparison,
                       comparison.ideal.isFinite,
                       comparison.product.isFinite,
                       comparison.diff.isFinite,
                       let direction = measurement.direction {
                        Text("베스트 \(CoorditFitLabResultMeasurement.number(comparison.ideal))")
                        Text("상품 \(CoorditFitLabResultMeasurement.number(comparison.product))")
                        Spacer(minLength: 0)
                        Text("\(CoorditFitLabResultMeasurement.signed(comparison.diff)) cm · \(direction.label)")
                            .fontWeight(.bold)
                    } else {
                        Text("비교 데이터 없음")
                        Spacer(minLength: 0)
                    }
                }
                .font(CoorditTypography.gmarketMedium(size: metrics.value(10), relativeTo: .caption))
                .foregroundStyle(Color.black)
                .padding(.horizontal, metrics.value(12))
                .padding(.vertical, metrics.value(10))
                .frame(maxWidth: .infinity, minHeight: metrics.value(44), alignment: .leading)
                .background(CoorditFitLabPalette.field)
                .clipShape(RoundedRectangle(cornerRadius: metrics.value(7)))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(measurement.title)
                .accessibilityValue(measurement.accessibilityValue)
                .accessibilityIdentifier("fitlab-measurement-\(measurement.key.rawValue)")
            }
        }
    }
}
#endif
