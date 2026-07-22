import SwiftUI

#if os(iOS)
import PhotosUI

extension CoorditClosetFamilyView {
    func detailScreen(
        metrics: CoorditResponsiveMetrics,
        variant: CoorditClosetCategory,
        item: CoorditClosetItem,
        screenIdentifier: String
    ) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: metrics.value(20)) {
                CoorditClosetTitleBar(title: "FIT DETAIL", metrics: metrics, horizontalOutset: 12) {
                    onRouteChange(.closetOverview)
                }

                HStack(alignment: .top, spacing: metrics.value(13)) {
                    PhotosPicker(selection: $detailPhotoSelection, matching: .images) {
                        ZStack(alignment: .bottom) {
                            CoorditClosetGarmentArtwork(imageData: item.imageData, metrics: metrics)

                            Text(item.imageData == nil ? "옷 사진 추가하기" : "변경하기")
                                .font(CoorditTypography.gmarketBold(size: metrics.value(9)))
                                .foregroundStyle(.white)
                                .padding(.horizontal, metrics.value(10))
                                .frame(height: metrics.value(24))
                                .background(CoorditClosetColors.navy.opacity(0.82))
                                .clipShape(Capsule())
                                .padding(.bottom, metrics.value(8))
                        }
                        .frame(width: metrics.value(168), height: metrics.value(158))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.imageData == nil ? "옷 사진 추가하기" : "옷 사진 변경하기")
                    .accessibilityIdentifier("closet-detail-garment-photo")
                    .accessibilityValue(item.imageData == nil ? "empty" : "selected")
                    .onChange(of: detailPhotoSelection) { _, newItem in
                        guard let newItem else { return }
                        loadDetailPhoto(newItem, for: item.id)
                    }

                    VStack(spacing: metrics.value(10)) {
                        Text(item.name)
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

                #if DEBUG
                if detailPhotoTestScenario != nil {
                    VStack {
                        Text("Detail photo test state")
                            .accessibilityIdentifier("closet-detail-photo-test-state")
                            .accessibilityValue(detailPhotoTestStates[item.id] ?? "empty")
                        Text("Detail photo test rejection")
                            .accessibilityIdentifier("closet-detail-photo-test-rejection")
                            .accessibilityValue(detailPhotoTestRejections[item.id] ?? "none")
                    }
                    .font(.system(size: 1))
                    .foregroundStyle(.clear)
                    .frame(width: 1, height: 1)
                }
                #endif

                HStack(spacing: metrics.value(9)) {
                    Image(variant == .top ? CoorditAssetNames.closetFitTop : CoorditAssetNames.closetFitBottom)
                        .resizable()
                        .scaledToFit()
                        .frame(width: metrics.value(111), height: metrics.value(230))
                        .background(CoorditClosetColors.card)
                        .clipShape(RoundedRectangle(cornerRadius: metrics.value(8)))

                    scorePanel(metrics: metrics, variant: variant, score: item.score)
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
        .accessibilityIdentifier("coordit-screen-\(screenIdentifier)")
        .onAppear {
            #if DEBUG
            runDetailPhotoTestScenario(for: item.id)
            #endif
        }
        .onDisappear {
            invalidateDetailPhotoLoad(for: item.id)
        }
    }

    private func scorePanel(metrics: CoorditResponsiveMetrics, variant: CoorditClosetCategory, score: Int) -> some View {
        VStack(alignment: .leading, spacing: metrics.value(8)) {
            Text("과거 기준치 기준")
                .font(CoorditTypography.gmarketMedium(size: metrics.value(10)))
                .foregroundStyle(CoorditClosetColors.navy.opacity(0.42))
            Text("FIT SCORE")
                .font(CoorditTypography.climate2019(size: metrics.value(22)))
                .foregroundStyle(CoorditClosetColors.navy)
            metricsGrid(metrics: metrics, values: scoreMetrics(for: variant))
            CoorditClosetPrimaryButton(title: "총점 | \(score)", metrics: metrics, height: 38) {}
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
