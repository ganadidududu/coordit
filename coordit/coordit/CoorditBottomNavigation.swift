import SwiftUI

#if os(iOS)
struct CoorditBottomNavigation: View {
    let selectedTab: Main01Tab?
    let scale: CGFloat
    let onTabSelection: (Main01Tab) -> Void

    var body: some View {
        CoorditLiquidGlassBottomNavigation(
            selectedTab: selectedTab,
            scale: scale,
            accessibilityIdentifier: "coordit-bottom-navigation",
            tabIdentifierPrefix: "coordit-tab",
            onTabSelection: onTabSelection
        )
    }
}
#endif
