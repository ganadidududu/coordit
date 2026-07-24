import SwiftUI

#if os(iOS)
struct CoorditBackTitleCard: View {
    let title: String
    let metrics: CoorditResponsiveMetrics
    let onBack: () -> Void

    var body: some View {
        Button(action: onBack) {
            HStack(spacing: metrics.value(15)) {
                Image(systemName: "chevron.left")
                    .font(.system(size: metrics.value(23), weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.82))
                    .frame(width: metrics.value(23), alignment: .leading)

                Text(title)
                    .font(CoorditTypography.climate2019(size: metrics.value(22), relativeTo: .headline))
                    .tracking(metrics.value(1.2))
                    .foregroundStyle(Color.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, metrics.value(26))
            .frame(width: metrics.value(372), height: metrics.value(60), alignment: .leading)
            .background(CoorditDesignTokens.ColorToken.panel)
            .clipShape(RoundedRectangle(cornerRadius: metrics.value(6), style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: metrics.value(10), y: metrics.value(4))
        }
        .coorditPressFeedback()
        .accessibilityIdentifier(title)
        .accessibilityLabel("\(title) 뒤로가기")
    }
}

struct CoorditPressFeedbackButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 10
    var pressedScale: CGFloat = 0.965
    var pressedOpacity: Double = 0.88
    var overlayOpacity: Double = 0.16

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(configuration.isPressed ? Color.black.opacity(overlayOpacity) : Color.clear)
                    .allowsHitTesting(false)
            }
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .opacity(configuration.isPressed ? pressedOpacity : 1)
            .animation(.linear(duration: 0.035), value: configuration.isPressed)
    }
}

extension View {
    func coorditPressFeedback(
        cornerRadius: CGFloat = 10,
        pressedScale: CGFloat = 0.965,
        pressedOpacity: Double = 0.88,
        overlayOpacity: Double = 0.16
    ) -> some View {
        buttonStyle(
            CoorditPressFeedbackButtonStyle(
                cornerRadius: cornerRadius,
                pressedScale: pressedScale,
                pressedOpacity: pressedOpacity,
                overlayOpacity: overlayOpacity
            )
        )
    }
}
#endif
