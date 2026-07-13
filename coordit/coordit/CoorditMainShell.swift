import SwiftUI

#if os(iOS)
struct CoorditMainShell: View {
    let route: CoorditFrameRoute
    let onTabSelection: (Main01Tab) -> Void

    var body: some View {
        GeometryReader { geometry in
            let metrics = CoorditResponsiveMetrics(size: geometry.size)

            ZStack {
                Main01DesignTokens.Colors.surface
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Main01ChromeBackground(scale: metrics.scale)

                VStack(spacing: 0) {
                    Main01Header(scale: metrics.scale)
                        .padding(.top, Main01DesignTokens.Metrics.headerTop * metrics.scale)

                    placeholderSurface(metrics: metrics)

                    Spacer(minLength: 0)

                    CoorditBottomNavigation(
                        selectedTab: route.selectedTab,
                        scale: metrics.scale,
                        onTabSelection: onTabSelection
                    )
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.light)
    }

    private func placeholderSurface(metrics: CoorditResponsiveMetrics) -> some View {
        let content = CoorditMockData.content(for: route)

        return VStack(alignment: .leading, spacing: metrics.value(8)) {
            Text(content.eyebrow)
                .font(CoorditTypography.climate(size: metrics.value(14)))
                .foregroundStyle(Main01DesignTokens.Colors.chrome)
            Text(content.title)
                .font(CoorditTypography.gmarketBold(size: metrics.value(18)))
                .foregroundStyle(Main01DesignTokens.Colors.chrome)
            Text(content.detail)
                .font(CoorditTypography.gmarketMedium(size: metrics.value(11)))
                .foregroundStyle(Main01DesignTokens.Colors.chrome.opacity(0.55))
        }
        .padding(metrics.value(18))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 252 / 255, green: 253 / 255, blue: 254 / 255))
        .clipShape(RoundedRectangle(cornerRadius: metrics.value(10)))
        .shadow(color: .black.opacity(0.08), radius: metrics.value(12), y: metrics.value(4))
        .padding(.top, metrics.value(26))
        .padding(.horizontal, metrics.value(16))
        .accessibilityIdentifier(route.visibleIdentifier)
    }
}
#endif
