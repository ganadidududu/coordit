import SwiftUI

#if os(iOS)
enum Main01DesignTokens {
    enum Colors {
        static let surface = Color(red: 247.0 / 255.0, green: 248.0 / 255.0, blue: 248.0 / 255.0)
        static let chrome = Color(red: 0.0, green: 12.0 / 255.0, blue: 64.0 / 255.0)
        static let foreground = Color(red: 242.0 / 255.0, green: 242.0 / 255.0, blue: 242.0 / 255.0)

        static func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> Color {
            Color(red: red / 255, green: green / 255, blue: blue / 255)
        }

        static let topChrome = LinearGradient(
            stops: [
                .init(color: chrome, location: 0.00),
                .init(color: chrome, location: 0.20),
                .init(color: rgb(20, 32, 84), location: 0.25),
                .init(color: rgb(49, 60, 111), location: 0.30),
                .init(color: rgb(77, 87, 133), location: 0.35),
                .init(color: rgb(105, 114, 153), location: 0.40),
                .init(color: rgb(131, 139, 172), location: 0.45),
                .init(color: rgb(153, 160, 187), location: 0.50),
                .init(color: rgb(171, 177, 199), location: 0.55),
                .init(color: rgb(186, 191, 209), location: 0.60),
                .init(color: rgb(202, 206, 220), location: 0.65),
                .init(color: rgb(215, 217, 228), location: 0.70),
                .init(color: rgb(225, 228, 235), location: 0.75),
                .init(color: rgb(233, 234, 239), location: 0.80),
                .init(color: rgb(239, 241, 243), location: 0.85),
                .init(color: rgb(243, 244, 246), location: 0.90),
                .init(color: rgb(245, 246, 247), location: 0.95),
                .init(color: surface, location: 1.00)
            ],
            startPoint: .top,
            endPoint: .bottom
        )

        static let chromeEdgeHighlight = LinearGradient(
            stops: [
                .init(color: surface.opacity(0.43), location: 0.000),
                .init(color: surface.opacity(0.36), location: 0.0125),
                .init(color: surface.opacity(0.28), location: 0.025),
                .init(color: surface.opacity(0.14), location: 0.030),
                .init(color: .clear, location: 0.050),
                .init(color: .clear, location: 0.950),
                .init(color: surface.opacity(0.14), location: 0.970),
                .init(color: surface.opacity(0.28), location: 0.975),
                .init(color: surface.opacity(0.36), location: 0.9875),
                .init(color: surface.opacity(0.43), location: 1.000)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )

        static let bottomChrome = LinearGradient(
            stops: [
                .init(color: surface, location: 0.000),
                .init(color: rgb(244, 245, 246), location: 0.060),
                .init(color: rgb(239, 240, 243), location: 0.120),
                .init(color: rgb(232, 234, 238), location: 0.182),
                .init(color: rgb(223, 225, 231), location: 0.247),
                .init(color: rgb(211, 214, 223), location: 0.310),
                .init(color: rgb(197, 201, 213), location: 0.375),
                .init(color: rgb(185, 189, 205), location: 0.437),
                .init(color: rgb(169, 173, 192), location: 0.505),
                .init(color: rgb(145, 151, 176), location: 0.565),
                .init(color: rgb(111, 119, 151), location: 0.637),
                .init(color: rgb(68, 79, 121), location: 0.700),
                .init(color: rgb(24, 36, 87), location: 0.762),
                .init(color: rgb(4, 16, 68), location: 0.820),
                .init(color: chrome, location: 0.900),
                .init(color: chrome, location: 1.000)
            ],
            startPoint: .top,
            endPoint: .bottom
        )

        static let bottomChromeContour = LinearGradient(
            stops: [
                .init(color: .clear, location: 0.00),
                .init(color: chrome.opacity(0.10), location: 0.05),
                .init(color: chrome.opacity(0.18), location: 0.13),
                .init(color: chrome.opacity(0.08), location: 0.31),
                .init(color: .clear, location: 0.50),
                .init(color: chrome.opacity(0.05), location: 0.62),
                .init(color: chrome.opacity(0.10), location: 0.93),
                .init(color: .clear, location: 1.00)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )

        static let bottomChromeContourMask = LinearGradient(
            stops: [
                .init(color: .clear, location: 0.00),
                .init(color: .black.opacity(0.35), location: 0.20),
                .init(color: .black.opacity(0.80), location: 0.50),
                .init(color: .black, location: 0.70),
                .init(color: .black, location: 1.00)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    enum Metrics {
        static let designWidth: CGFloat = 402
        static let headerTop: CGFloat = 59
        static let headerWidth: CGFloat = 333
        static let headerHeight: CGFloat = 38.8117
        static let headerIcon: CGFloat = 30
        static let logoWidth: CGFloat = 139
        static let topChromeHeight: CGFloat = 200
        static let bottomChromeHeight: CGFloat = 155
        static let navHeight: CGFloat = 92
        static let navContentBottom: CGFloat = 7
        static let navLeading: CGFloat = 42.33
        static let homeWidth: CGFloat = 84
        static let homeToFitLab: CGFloat = 25
        static let fitLabWidth: CGFloat = 93.5
        static let fitLabToCloset: CGFloat = 21.5
        static let closetWidth: CGFloat = 98.18
    }

    enum Typography {
        static func navLabel(size: CGFloat) -> Font {
            .custom("ClimateCrisisKR-VF-2010", size: size, relativeTo: .caption)
        }

        static func logo(_ instance: String, size: CGFloat) -> Font {
            .custom("ClimateCrisisKR-VF-\(instance)", size: size, relativeTo: .title2)
        }
    }
}
#endif
