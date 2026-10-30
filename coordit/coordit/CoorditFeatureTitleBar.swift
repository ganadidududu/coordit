import SwiftUI

#if os(iOS)
struct CoorditFeatureTitleBar: View {
    let title: String
    let metrics: CoorditResponsiveMetrics
    let accessibilityLabel: String
    var onHelp: (() -> Void)? = nil
    var helpIdentifier: String = ""
    var height: CGFloat = 60
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: metrics.value(8)) {
            Button(action: onBack) {
                HStack(spacing: metrics.value(18)) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: metrics.value(25), weight: .bold))
                    Text(title)
                        .font(CoorditTypography.gmarketBold(size: metrics.value(22), relativeTo: .headline))
                        .tracking(metrics.value(1.5))
                        .lineLimit(1)
                        .minimumScaleFactor(0.35)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(.black)
                .frame(height: metrics.value(height))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .coorditPressFeedback()
            .accessibilityLabel(accessibilityLabel)

            if let onHelp {
                CoorditCompactActionButton(title: "사용법", symbol: "questionmark.circle", metrics: metrics, action: onHelp)
                    .accessibilityLabel("\(title) 사용법 다시 보기")
                    .accessibilityIdentifier(helpIdentifier)
            }
        }
        .padding(.leading, metrics.value(29))
        .padding(.trailing, metrics.value(onHelp == nil ? 29 : 14))
        .frame(width: metrics.value(CoorditResponsiveMetrics.designWidth - 32))
        .background(CoorditDesignTokens.ColorToken.panel)
        .clipShape(RoundedRectangle(cornerRadius: metrics.value(7)))
    }
}

struct CoorditCompactActionButton: View {
    let title: String
    let symbol: String
    let metrics: CoorditResponsiveMetrics
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(CoorditTypography.gmarketMedium(size: metrics.value(11), relativeTo: .caption))
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(CoorditDesignTokens.ColorToken.ink)
                .padding(.horizontal, metrics.value(12))
                .padding(.vertical, metrics.value(9))
                .background(CoorditDesignTokens.ColorToken.field, in: Capsule())
                .overlay(Capsule().stroke(CoorditDesignTokens.ColorToken.ink.opacity(0.12), lineWidth: 1))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .coorditPressFeedback()
    }
}
#endif
