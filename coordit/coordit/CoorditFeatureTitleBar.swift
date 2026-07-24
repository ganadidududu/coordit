import SwiftUI

#if os(iOS)
struct CoorditFeatureTitleBar: View {
    let title: String
    let metrics: CoorditResponsiveMetrics
    let accessibilityLabel: String
    let onBack: () -> Void

    var body: some View {
        Button(action: onBack) {
            HStack(spacing: metrics.value(18)) {
                Image(systemName: "chevron.left")
                    .font(.system(size: metrics.value(25), weight: .bold))
                Text(title)
                    .font(CoorditTypography.gmarketBold(size: metrics.value(22), relativeTo: .headline))
                    .tracking(metrics.value(1.5))
                Spacer(minLength: 0)
            }
            .foregroundStyle(.black)
            .padding(.horizontal, metrics.value(29))
            .frame(width: metrics.value(CoorditResponsiveMetrics.designWidth - 32))
            .frame(height: metrics.value(60))
            .background(CoorditDesignTokens.ColorToken.panel)
            .clipShape(RoundedRectangle(cornerRadius: metrics.value(7)))
        }
        .coorditPressFeedback()
        .accessibilityLabel(accessibilityLabel)
    }
}
#endif
