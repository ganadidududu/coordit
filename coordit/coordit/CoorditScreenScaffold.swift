import SwiftUI

#if os(iOS)
struct CoorditScreenScaffold<Content: View>: View {
    let route: CoorditFrameRoute
    let onRouteChange: (CoorditFrameRoute) -> Void
    let contentTop: CGFloat
    let contentBottom: CGFloat
    @ViewBuilder let content: (CoorditResponsiveMetrics) -> Content

    init(
        route: CoorditFrameRoute,
        onRouteChange: @escaping (CoorditFrameRoute) -> Void,
        contentTop: CGFloat = 120,
        contentBottom: CGFloat = 80,
        @ViewBuilder content: @escaping (CoorditResponsiveMetrics) -> Content
    ) {
        self.route = route
        self.onRouteChange = onRouteChange
        self.contentTop = contentTop
        self.contentBottom = contentBottom
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            let metrics = CoorditResponsiveMetrics(size: geometry.size)

            ZStack(alignment: .top) {
                Main01DesignTokens.Colors.surface
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Main01ChromeBackground(scale: metrics.scale)

                content(metrics)
                    .padding(.top, metrics.value(contentTop))
                    .padding(.bottom, metrics.value(contentBottom))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                VStack(spacing: 0) {
                    Main01Header(scale: metrics.scale) {
                        onRouteChange(.myPage)
                    }
                        .padding(.top, Main01DesignTokens.Metrics.headerTop * metrics.scale)

                    Spacer(minLength: 0)

                    CoorditBottomNavigation(
                        selectedTab: route.selectedTab,
                        scale: metrics.scale
                    ) { selectedTab in
                        onRouteChange(CoorditFrameRoute.route(for: selectedTab, from: route))
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.light)
    }
}
#endif
