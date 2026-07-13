import SwiftUI

#if os(iOS)
extension CoorditClosetFamilyView {
    func detailScreen(metrics: CoorditResponsiveMetrics, variant: CoorditClosetCategory) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: metrics.value(20)) {
                CoorditClosetTitleBar(title: "FIT DETAIL", metrics: metrics) {
                    onRouteChange(.closetOverview)
                }

                HStack(alignment: .top, spacing: metrics.value(13)) {
                    RoundedRectangle(cornerRadius: metrics.value(8))
                        .fill(Color(red: 231 / 255, green: 234 / 255, blue: 241 / 255))
                        .frame(width: metrics.value(168), height: metrics.value(158))
                        .overlay(
                            RoundedRectangle(cornerRadius: metrics.value(8))
                                .stroke(Color(red: 214 / 255, green: 220 / 255, blue: 232 / 255), lineWidth: metrics.value(0.7))
                        )

                    VStack(spacing: metrics.value(10)) {
                        Text("Wide Denim")
                            .font(CoorditTypography.gmarketBold(size: metrics.value(23)))
                            .foregroundStyle(.black)
                        Image(CoorditAssetNames.stars)
                            .resizable()
                            .scaledToFit()
                            .frame(width: metrics.value(143), height: metrics.value(31))
                            .accessibilityHidden(true)
                        detailAction("메모 추가하기", metrics: metrics) {}
                        detailAction("내 옷장에서 삭제하기", metrics: metrics) {}
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.top, metrics.value(18))

                HStack(spacing: metrics.value(9)) {
                    Image(variant == .top ? CoorditAssetNames.closetFitTop : CoorditAssetNames.closetFitBottom)
                        .resizable()
                        .scaledToFit()
                        .frame(width: metrics.value(111), height: metrics.value(230))
                        .background(CoorditClosetColors.card)
                        .clipShape(RoundedRectangle(cornerRadius: metrics.value(8)))

                    scorePanel(metrics: metrics, variant: variant)
                        .frame(height: metrics.value(230))
                }
                .padding(.top, metrics.value(6))

                HStack {
                    Text("Score Description")
                        .font(CoorditTypography.mona12(size: metrics.value(17)))
                        .foregroundStyle(.black)
                    Spacer(minLength: 0)
                    detailInfoButton(metrics: metrics)
                }
                .padding(.horizontal, metrics.value(18))
                .frame(height: metrics.value(43))
                .background(CoorditClosetColors.card)
                .clipShape(RoundedRectangle(cornerRadius: metrics.value(7)))
                .padding(.top, metrics.value(1))

                CoorditClosetPrimaryButton(title: "현재 기준치로 재평가", metrics: metrics, height: 39) {
                    detailVariant = variant == .top ? .bottom : .top
                    onRouteChange(variant == .top ? .closetDetailBottom : .closetDetailTop)
                }
                .accessibilityIdentifier("closet-reevaluate")
                .padding(.top, metrics.value(2))
            }
            .padding(.horizontal, metrics.value(27))
            .padding(.bottom, metrics.value(28))
        }
        .accessibilityIdentifier("coordit-screen-\(variant == .top ? "closet-detail-top" : "closet-detail-bottom")")
    }

    private func scorePanel(metrics: CoorditResponsiveMetrics, variant: CoorditClosetCategory) -> some View {
        VStack(alignment: .leading, spacing: metrics.value(8)) {
            Text("과거 기준치 기준")
                .font(CoorditTypography.gmarketMedium(size: metrics.value(10)))
                .foregroundStyle(CoorditClosetColors.navy.opacity(0.42))
            Text("FIT SCORE")
                .font(CoorditTypography.climate2019(size: metrics.value(22)))
                .foregroundStyle(CoorditClosetColors.navy)
            metricsGrid(metrics: metrics, values: scoreMetrics(for: variant))
            CoorditClosetPrimaryButton(title: "총점 |", metrics: metrics, height: 38) {}
        }
        .padding(metrics.value(11))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CoorditClosetColors.card)
        .clipShape(RoundedRectangle(cornerRadius: metrics.value(8)))
    }

    private func scoreMetrics(for variant: CoorditClosetCategory) -> [(String, String, Color)] {
        let signedColors: [Color] = variant == .top
            ? [CoorditClosetColors.navy, CoorditClosetColors.navy, CoorditClosetColors.navy, CoorditClosetColors.navy]
            : [CoorditClosetColors.green, CoorditClosetColors.red, CoorditClosetColors.red, CoorditClosetColors.green]
        return [
            ("+1 cm", "어깨", signedColors[0]),
            ("-5 cm", "가슴", signedColors[1]),
            ("-3 cm", "총장", signedColors[2]),
            ("+0.5 cm", "소매", signedColors[3]),
        ]
    }

    private func detailAction(_ title: String, metrics: CoorditResponsiveMetrics, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(CoorditTypography.gmarketMedium(size: metrics.value(10)))
                .foregroundStyle(title == "내 옷장에서 삭제하기" ? .black : CoorditClosetColors.navy.opacity(0.5))
                .frame(maxWidth: .infinity)
                .frame(height: metrics.value(33))
                .background(CoorditClosetColors.card)
                .clipShape(RoundedRectangle(cornerRadius: metrics.value(7)))
        }
        .buttonStyle(.plain)
    }

    private func detailInfoButton(metrics: CoorditResponsiveMetrics) -> some View {
        Button("자세히 보기") {}
            .font(CoorditTypography.gmarketMedium(size: metrics.value(12)))
            .foregroundStyle(.white)
            .frame(width: metrics.value(96), height: metrics.value(32))
            .background(CoorditClosetColors.navy)
            .clipShape(Capsule())
    }
}
#endif
