import SwiftUI

#if os(iOS)
enum CoorditTypography {
    enum PostScriptName {
        static let climateCrisis = "ClimateCrisisKR-VF"
        static let gmarketSansLight = "GmarketSansLight"
        static let gmarketSansMedium = "GmarketSansMedium"
        static let gmarketSansBold = "GmarketSansBold"
        static let mona12 = "Mona12TextHK-Regular"
    }

    static func climate(size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom(PostScriptName.climateCrisis, size: size, relativeTo: textStyle)
    }

    static func climate2010(size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom("ClimateCrisisKR-VF-2010", size: size, relativeTo: textStyle)
    }

    static func climate2019(size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom("ClimateCrisisKR-VF-2019", size: size, relativeTo: textStyle)
    }

    static func climate2030(size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom("ClimateCrisisKR-VF-2030", size: size, relativeTo: textStyle)
    }

    static func gmarketLight(size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom(PostScriptName.gmarketSansLight, size: size, relativeTo: textStyle)
    }

    static func gmarketMedium(size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom(PostScriptName.gmarketSansMedium, size: size, relativeTo: textStyle)
    }

    static func gmarketBold(size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom(PostScriptName.gmarketSansBold, size: size, relativeTo: textStyle)
    }

    static func mona12(size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom(PostScriptName.mona12, size: size, relativeTo: textStyle)
    }
}
#endif
