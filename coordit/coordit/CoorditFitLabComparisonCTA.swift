import SwiftUI

#if os(iOS)
struct CoorditFitLabComparisonCTA: View {
    let metrics: CoorditResponsiveMetrics
    let action: () -> Void

    var body: some View {
        VStack(spacing: metrics.value(8)) {
            Button("내 옷과 비교하기", action: action)
                .buttonStyle(CoorditContentActionButtonStyle(prominence: .primary))
                .accessibilityIdentifier("fitlab-show-comparison")
            Text("실타래 1개가 소모됩니다.")
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
