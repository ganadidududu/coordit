import SwiftUI

#if os(iOS)
enum CoorditDesignTokens {
    enum ColorToken {
        static let appBackground = rgb(247, 248, 248)
        static let ink = rgb(0, 12, 64)
        static let muted = rgb(126, 132, 146)
        static let fitMuted = rgb(127, 133, 150)
        static let panel = rgb(252, 253, 254)
        static let field = rgb(245, 247, 252)
        static let settingsField = rgb(246, 247, 249)
        static let closetField = rgb(242, 244, 248)
        static let closetMuted = rgb(184, 193, 211)
        static let placeholder = rgb(231, 235, 244)
        static let line = rgb(225, 229, 234)
        static let blue = rgb(25, 64, 150)
        static let cyan = rgb(0, 172, 207)
        static let green = rgb(0, 180, 67)
        static let red = rgb(235, 37, 73)
        static let danger = rgb(234, 74, 86)
        static let warmLine = rgb(255, 188, 56)

        private static func rgb(_ red: Double, _ green: Double, _ blue: Double) -> Color {
            Color(red: red / 255, green: green / 255, blue: blue / 255)
        }
    }

    enum Spacing {
        static let pageInset: CGFloat = 22
        static let panelPadding: CGFloat = 20
        static let navHeight: CGFloat = 86
        static let cornerRadius: CGFloat = 10
    }
}
#endif
