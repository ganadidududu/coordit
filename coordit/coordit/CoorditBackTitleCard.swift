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
        .buttonStyle(.plain)
        .accessibilityIdentifier(title)
        .accessibilityLabel("\(title) 뒤로가기")
    }
}
#endif
