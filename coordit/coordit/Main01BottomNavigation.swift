import SwiftUI

#if os(iOS)
struct Main01BottomNavigation: View {
    @Binding var selectedTab: Main01Tab
    let scale: CGFloat
    let onTabSelection: (Main01Tab) -> Void

    init(
        selectedTab: Binding<Main01Tab>,
        scale: CGFloat,
        onTabSelection: @escaping (Main01Tab) -> Void = { _ in }
    ) {
        _selectedTab = selectedTab
        self.scale = scale
        self.onTabSelection = onTabSelection
    }

    var body: some View {
        CoorditLiquidGlassBottomNavigation(
            selectedTab: selectedTab,
            scale: scale,
            accessibilityIdentifier: "main01-bottom-navigation",
            tabIdentifierPrefix: "main01-tab"
        ) { tab in
            selectedTab = tab
            onTabSelection(tab)
        }
    }
}
#endif
