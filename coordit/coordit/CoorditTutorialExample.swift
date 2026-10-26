import SwiftUI

#if os(iOS)
enum CoorditTutorialExample {
    static let link = "https://example.coordit.invalid/products/basic"

    static func matches(_ url: URL?) -> Bool {
        url?.absoluteString == link
    }

    static func product(category: CoorditFitLabCategory) -> CoorditFitLabURLPrefillResponse {
        let upper = category.garmentKind == .upper
        return .init(
            productName: "[예시] 베이직 \(category.koreanTitle)",
            brand: nil, mallName: "예시 체험", productUrl: URL(string: link)!,
            category: category, fitType: "regular", parsingStatus: "confirmed",
            sizes: ["S", "M", "L"].enumerated().map { index, label in
                let offset = Double(index) * 2
                return .init(
                    sizeLabel: label,
                    shoulderWidth: upper ? 44 + offset : nil,
                    chestWidth: upper ? 50 + offset : nil,
                    totalLength: upper ? 66 + offset : nil,
                    sleeveLength: upper ? 20 + offset : nil,
                    waistWidth: upper ? nil : 36 + offset,
                    hipWidth: upper ? nil : 48 + offset,
                    rise: upper ? nil : 27 + offset,
                    outseam: upper ? nil : 96 + offset
                )
            }
        )
    }

    static func references(category: CoorditFitLabCategory) -> [CoorditFitLabReferenceRow] {
        [.init(id: "tutorial-reference", clothingItemID: "tutorial-clothing",
               nickname: "[예시] 나에게 잘 맞는 \(category.koreanTitle)", category: category,
               fitType: "regular", preferenceScore: 5, isActive: true)]
    }

    static func recommendation(for draft: CoorditFitLabDraft) -> CoorditFitLabRecommendationResponse {
        let selected = draft.sizes.first(where: { $0.label == "M" }) ?? draft.sizes[0]
        let scores = draft.sizes.map { row in
            CoorditFitLabReportResponse.ChartData.SizeScore(
                sizeLabel: row.label, fitScore: row.id == selected.id ? 95 : 82,
                fitLabel: "예시 점수", weightedFitDistance: row.id == selected.id ? 0.5 : 2,
                recommendationConfidence: "example"
            )
        }
        return .init(
            fitAnalysisResultID: "tutorial-example", recommendedSize: selected.label,
            fitScore: 95, fitLabel: "예시 점수", fitComment: "흐름을 설명하기 위한 예시 결과예요.",
            recommendationConfidence: "example",
            diff: selected.measurements.mapValues { _ in 1 }, allSizeScores: scores
        )
    }

    static func report(for recommendation: CoorditFitLabRecommendationResponse) -> CoorditFitLabReportResponse {
        .init(
            fitAnalysisResultID: recommendation.fitAnalysisResultID, source: "example",
            report: .init(
                title: "예시 핏 리포트", summary: "사이즈별 점수와 기준 옷과의 차이를 이렇게 확인할 수 있어요.",
                cautions: ["체험용으로 준비한 점수이며 실제 체형이나 입력값을 분석한 결과가 아니에요."],
                nextActions: ["체험을 마치고 내 상품과 기준 옷으로 분석해 보세요."]
            ),
            chartData: .init(sizeScoreRanking: recommendation.allSizeScores)
        )
    }
}

struct CoorditExampleNotice: View {
    var body: some View {
        Text("예시 체험 · 실제 저장이나 실타래 사용 없이 흐름을 확인해요.")
            .font(CoorditTypography.gmarketMedium(size: 12))
            .foregroundStyle(CoorditFitLabPalette.ink)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("tutorial-example-notice")
    }
}

extension CoorditFitLabDraft {
    var isTutorialExample: Bool { CoorditTutorialExample.matches(productURL) }
}

extension CoorditClosetDraft {
    var isTutorialExample: Bool {
        CoorditTutorialExample.matches(URL(string: productLink.trimmingCharacters(in: .whitespacesAndNewlines)))
    }
}
#endif
