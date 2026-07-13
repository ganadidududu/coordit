import SwiftUI

#if os(iOS)
struct CoorditMain01Screen: View {
    @State private var selectedTab: Main01Tab
    private let onTabSelection: (Main01Tab) -> Void

    init(
        initialTab: Main01Tab = .home,
        onTabSelection: @escaping (Main01Tab) -> Void = { _ in }
    ) {
        _selectedTab = State(initialValue: initialTab)
        self.onTabSelection = onTabSelection
    }

    var body: some View {
        GeometryReader { geometry in
            let scale = geometry.size.width / Main01DesignTokens.Metrics.designWidth

            ZStack {
                Rectangle()
                    .fill(Main01DesignTokens.Colors.surface)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Main01ChromeBackground(scale: scale)

                VStack(spacing: 0) {
                    Main01Header(scale: scale)
                        .padding(.top, Main01DesignTokens.Metrics.headerTop * scale)

                    Spacer(minLength: 0)

                    Main01BottomNavigation(
                        selectedTab: $selectedTab,
                        scale: scale,
                        onTabSelection: onTabSelection
                    )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
        .preferredColorScheme(.light)
        .accessibilityIdentifier("main01-screen")
    }
}
#endif
