import Foundation
import SwiftUI

#if os(iOS)
struct CoorditFitLabSizeFact: Codable, Equatable, Sendable {
    let measurement: CoorditFitLabMeasurementKey
    let reference: Double
    let product: Double
    let diff: Double
}

struct CoorditFitLabScoreSelection {
    typealias Chart = CoorditFitLabReportResponse.ChartData
    let sizeLabel: String
    let isRecommended: Bool
    let fitPointScores: [Chart.FitPointScore]
    let measurementScores: [Chart.MeasurementScore]

    static func pointDescription(_ key: String) -> String {
        switch key {
        case "silhouette": "옷 종류별 주요 부위와 길이의 유사도"
        case "mobility": "어깨·소매 또는 힙·밑위의 유사도"
        case "layering": "가슴·어깨 공간의 유사도"
        default: ""
        }
    }

    init(
        selected: CoorditFitLabSizeOption?,
        recommendation: CoorditFitLabRecommendationResponse?,
        report: CoorditFitLabReportResponse?
    ) {
        let label = selected?.sizeLabel ?? recommendation?.recommendedSize ?? "-"
        sizeLabel = label
        isRecommended = selected?.isRecommended ?? true
        if isRecommended {
            fitPointScores = report?.chartData.fitPointScores ?? []
            measurementScores = report?.chartData.measurementScores ?? []
            return
        }
        let row = recommendation?.allSizeScores.first { $0.sizeLabel == label }
        fitPointScores = [("silhouette", "실루엣"), ("mobility", "활동성"), ("layering", "레이어링")].compactMap { key, label in
            guard let score = row?.semanticSubscores?[key], score.isFinite, (0...100).contains(score) else { return nil }
            return .init(key: key, label: label, score: score)
        }
        measurementScores = (selected?.measurements ?? []).compactMap { item in
            guard let score = row?.measurementSubscores?[item.key.rawValue],
                  score.isFinite, (0...100).contains(score),
                  let comparison = item.comparison else { return nil }
            return .init(measurement: item.key, label: item.title, score: score, diff: comparison.diff, status: comparison.status)
        }
    }
}

struct CoorditFitLabComparisonNote: View {
    let selected: String
    let recommended: String
    let missingScores: Bool
    let metrics: CoorditResponsiveMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.value(6)) {
            Text("비교 중 \(selected) · 추천 \(recommended)")
                .font(CoorditTypography.gmarketBold(size: metrics.value(12), relativeTo: .body))
            Text("사이즈를 선택하면 점수와 실측 비교가 함께 바뀌어요.")
                .font(CoorditTypography.gmarketMedium(size: metrics.value(10), relativeTo: .caption))
                .foregroundStyle(CoorditFitLabPalette.muted)
            if missingScores {
                Text("이 사이즈의 세부 점수는 저장되어 있지 않아요. 상품 사이즈표와 함께 확인해 주세요.")
                    .font(CoorditTypography.gmarketMedium(size: metrics.value(11), relativeTo: .body))
                    .accessibilityIdentifier("fitlab-alternative-scores-unavailable")
            }
        }
        .foregroundStyle(CoorditFitLabPalette.ink)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("fitlab-comparison-basis")
    }
}
#endif
