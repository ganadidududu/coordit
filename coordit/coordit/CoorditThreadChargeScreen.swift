import SwiftUI

#if os(iOS)
extension CoorditMyPageFamilyView {
    func threadCharge(metrics: CoorditResponsiveMetrics) -> some View {
        VStack(spacing: metrics.value(18)) {
            pageHeader("실타래 충전", metrics: metrics)

            HStack(spacing: metrics.value(12)) {
                Image(CoorditAssetNames.yarn)
                    .resizable()
                    .scaledToFit()
                    .frame(width: metrics.value(50), height: metrics.value(50))

                VStack(alignment: .leading, spacing: metrics.value(4)) {
                    Text("보유 실타래")
                        .font(CoorditTypography.gmarketBold(size: metrics.value(12), relativeTo: .subheadline))
                        .foregroundStyle(CoorditSettingsStyle.muted)
                    Text("36 실타래")
                        .font(CoorditTypography.gmarketBold(size: metrics.value(29), relativeTo: .title))
                        .foregroundStyle(CoorditSettingsStyle.ink)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, metrics.value(18))
            .frame(height: metrics.value(82))
            .background(CoorditSettingsStyle.panel)
            .clipShape(RoundedRectangle(cornerRadius: metrics.value(20), style: .continuous))

            Button(action: {}) {
                HStack(spacing: metrics.value(16)) {
                    Image(CoorditAssetNames.rechargePlay)
                        .resizable()
                        .scaledToFit()
                        .frame(width: metrics.value(45), height: metrics.value(45))

                    Text("광고 보고 실타래 충전하기")
                        .font(CoorditTypography.gmarketBold(size: metrics.value(18), relativeTo: .headline))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                    CoorditSettingsChevron(metrics: metrics, color: .white)
                }
                .padding(.horizontal, metrics.value(15))
                .frame(height: metrics.value(128))
                .background(
                    LinearGradient(
                        colors: [CoorditSettingsStyle.ink, Color(red: 74 / 255, green: 85 / 255, blue: 132 / 255)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: metrics.value(6), style: .continuous))
                .shadow(color: CoorditSettingsStyle.ink.opacity(0.35), radius: metrics.value(18), y: metrics.value(8))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("광고 보고 실타래 충전하기")

            VStack(spacing: metrics.value(19)) {
                yarnPurchaseRow(amount: "5 실타래", price: "1,500원", highlighted: false, metrics: metrics)
                yarnPurchaseRow(amount: "10 실타래", price: "2,500원", highlighted: true, metrics: metrics)
                yarnPurchaseRow(amount: "20 실타래", price: "4,000원", highlighted: false, metrics: metrics)
            }
        }
    }

    private func yarnPurchaseRow(
        amount: String,
        price: String,
        highlighted: Bool,
        metrics: CoorditResponsiveMetrics
    ) -> some View {
        Button(action: {}) {
            HStack(spacing: metrics.value(12)) {
                Image(CoorditAssetNames.yarn)
                    .resizable()
                    .scaledToFit()
                    .frame(width: metrics.value(46), height: metrics.value(46))

                VStack(alignment: .leading, spacing: metrics.value(3)) {
                    Text(amount)
                        .font(CoorditTypography.gmarketBold(size: metrics.value(16), relativeTo: .headline))
                        .foregroundStyle(.black)
                    Text("실타래 충전")
                        .font(CoorditTypography.gmarketMedium(size: metrics.value(9), relativeTo: .caption))
                        .foregroundStyle(CoorditSettingsStyle.muted)
                }

                Spacer(minLength: 0)

                Text(price)
                    .font(CoorditTypography.gmarketBold(size: metrics.value(13), relativeTo: .caption))
                    .foregroundStyle(.white)
                    .padding(.horizontal, metrics.value(12))
                    .frame(height: metrics.value(31))
                    .background(CoorditSettingsStyle.ink)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, metrics.value(16))
            .frame(height: metrics.value(64))
            .background(CoorditSettingsStyle.panel)
            .clipShape(RoundedRectangle(cornerRadius: metrics.value(7), style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: metrics.value(7), style: .continuous)
                    .stroke(highlighted ? CoorditSettingsStyle.warmLine : CoorditSettingsStyle.line, lineWidth: highlighted ? 1.5 : 1)
            }
            .shadow(color: .black.opacity(0.035), radius: metrics.value(8), y: metrics.value(3))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(amount)
    }
}
#endif
