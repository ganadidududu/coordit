import SwiftUI

#if os(iOS)
struct CoorditFitLabHistoryDetailScreen: View {
    let metrics: CoorditResponsiveMetrics
    let onRouteChange: (CoorditFrameRoute) -> Void

    var body: some View {
        VStack(spacing: metrics.value(24)) {
            HStack(alignment: .top, spacing: metrics.value(12)) {
                RoundedRectangle(cornerRadius: metrics.value(7))
                    .fill(CoorditFitLabPalette.empty)
                    .frame(width: metrics.value(126), height: metrics.value(142))

                VStack(alignment: .leading, spacing: metrics.value(7)) {
                    Text("Wide Denim")
                        .font(CoorditTypography.gmarketBold(size: metrics.value(19), relativeTo: .title3))
                        .foregroundStyle(Color.black)

                    HStack(spacing: metrics.value(8)) {
                        CoorditFitLabStars(metrics: metrics)
                        Spacer(minLength: 0)
                        Button("별점 수정하기") {}
                            .font(CoorditTypography.gmarketMedium(size: metrics.value(6), relativeTo: .caption2))
                            .foregroundStyle(CoorditFitLabPalette.muted)
                    }
                    .padding(.horizontal, metrics.value(11))
                    .frame(width: metrics.value(174), height: metrics.value(27))
                    .background(CoorditFitLabPalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: metrics.value(6)))

                    Button("메모 추가하기") {}
                        .font(CoorditTypography.gmarketMedium(size: metrics.value(10), relativeTo: .caption))
                        .foregroundStyle(CoorditFitLabPalette.muted)
                        .frame(width: metrics.value(174), height: metrics.value(48))
                        .background(CoorditFitLabPalette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: metrics.value(6)))

                    Button("내 옷장에서 삭제하기") {}
                        .font(CoorditTypography.gmarketBold(size: metrics.value(10), relativeTo: .caption))
                        .foregroundStyle(Color.black.opacity(0.78))
                        .frame(width: metrics.value(174), height: metrics.value(26))
                        .background(CoorditFitLabPalette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: metrics.value(6)))
                }
            }
            .padding(metrics.value(11))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CoorditFitLabPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: metrics.value(7)))

            HStack(spacing: metrics.value(8)) {
                CoorditFitLabMannequinPanel(assetName: CoorditAssetNames.fitUpper, metrics: metrics)
                    .frame(width: metrics.value(101), height: metrics.value(189))

                CoorditFitLabScoreCard(variant: .history, metrics: metrics)
                    .frame(width: metrics.value(209), height: metrics.value(189))
            }

            CoorditFitLabDescriptionCard(metrics: metrics, compact: true) {
                onRouteChange(.fitLabResultTop)
            }
            .frame(height: metrics.value(44))

            CoorditFitLabPrimaryButton(title: "현재 기준치로 재평가", metrics: metrics) {
                onRouteChange(.fitLabLoading)
            }
            .padding(.top, metrics.value(11))
        }
        .padding(.horizontal, metrics.value(30))
    }
}

struct CoorditFitLabMetric: Identifiable {
    let id: String
    let value: String
    let label: String
}

enum CoorditFitLabResultVariant {
    case top
    case bottom
    case history

    var assetName: String {
        switch self {
        case .top, .history:
            CoorditAssetNames.fitUpper
        case .bottom:
            CoorditAssetNames.fitLower
        }
    }

    var scoreBasis: String {
        switch self {
        case .history:
            "과거 기준치 기준"
        case .top, .bottom:
            "현재 베스트 스코어 기준"
        }
    }

    var metrics: [CoorditFitLabMetric] {
        [
            CoorditFitLabMetric(id: "shoulder", value: "+1 cm", label: "어깨"),
            CoorditFitLabMetric(id: "chest", value: "-5 cm", label: "가슴"),
            CoorditFitLabMetric(id: "length", value: "-3 cm", label: "총장"),
            CoorditFitLabMetric(id: "sleeve", value: "+0.5 cm", label: "소매")
        ]
    }
}
#endif
