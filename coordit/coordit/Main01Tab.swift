import SwiftUI

#if os(iOS)
enum Main01Tab: String, CaseIterable, Identifiable {
    case home
    case fitLab
    case closet

    var id: Self { self }

    var title: String {
        switch self {
        case .home: "HOME"
        case .fitLab: "FIT LAB"
        case .closet: "CLOSET"
        }
    }

    var assetName: String {
        switch self {
        case .home: "FigmaTabHome"
        case .fitLab: "FigmaTabFit"
        case .closet: "FigmaTabCloset"
        }
    }

    var iconSize: CGSize {
        switch self {
        case .home: CGSize(width: 20, height: 20)
        case .fitLab: CGSize(width: 19, height: 15)
        case .closet: CGSize(width: 19.01, height: 19)
        }
    }

    var tracking: CGFloat {
        switch self {
        case .home: 0.24
        case .fitLab, .closet: -0.8
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .home: 10.8
        case .fitLab: 11.5
        case .closet: 12
        }
    }
}
#endif
