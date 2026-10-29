import SwiftUI

#if os(iOS)
struct CoorditFitLabComparisonCTA: View {
    let metrics: CoorditResponsiveMetrics
    let action: () -> Void

    var body: some View {
        VStack(spacing: metrics.value(8)) {
            Text("이 옷, 나한테는 어떨까요?")
                .font(CoorditTypography.gmarketBold(size: metrics.value(14), relativeTo: .headline))
                .foregroundStyle(CoorditFitLabPalette.ink)
            Button(action: action) {
                HStack(spacing: metrics.value(12)) {
                    Image(systemName: "tshirt")
                    Text("내 옷과 비교하기")
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.right")
                }
                .font(CoorditTypography.gmarketBold(size: metrics.value(17), relativeTo: .headline))
                .foregroundStyle(.white)
                .padding(.horizontal, metrics.value(20))
                .frame(maxWidth: .infinity, minHeight: metrics.value(58))
                .background(CoorditFitLabPalette.ink.gradient, in: RoundedRectangle(cornerRadius: metrics.value(13)))
                .overlay {
                    RoundedRectangle(cornerRadius: metrics.value(13))
                        .stroke(.white.opacity(0.24), lineWidth: 1)
                }
                .shadow(color: CoorditFitLabPalette.ink.opacity(0.23), radius: metrics.value(10), y: metrics.value(5))
            }
            .coorditPressFeedback(cornerRadius: metrics.value(13))
            .accessibilityIdentifier("fitlab-show-comparison")
            Text("추천 사이즈 · 부위별 차이   |   비교 시작 시 실타래 1개")
                .font(CoorditTypography.gmarketMedium(size: metrics.value(10), relativeTo: .caption))
                .foregroundStyle(CoorditFitLabPalette.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("fitlab-comparison-cta")
    }
}
#endif
