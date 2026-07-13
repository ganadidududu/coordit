import Foundation

#if os(iOS)
enum CoorditFrameRoute: String, CaseIterable, Identifiable {
    case main01
    case splash
    case main04
    case fitLabInput = "fitlab-input"
    case fitLabLoading = "fitlab-loading"
    case fitLabResultTop = "fitlab-result-top"
    case fitLabResultBottom = "fitlab-result-bottom"
    case fitLabHistoryRegister = "fitlab-history-register"
    case fitLabHistoryDetail = "fitlab-history-detail"
    case myPage = "mypage"
    case myPageThreadCharge = "mypage-thread-charge"
    case myPageBody = "mypage-body"
    case myPageAccount = "mypage-account"
    case myPagePrivacy = "mypage-privacy"
    case myPageAppSettings = "mypage-app-settings"
    case myPageNotifications = "mypage-notifications"
    case closetOverview = "closet-overview"
    case closetDetailTop = "closet-detail-top"
    case closetDetailBottom = "closet-detail-bottom"

    var id: Self { self }

    static func testingLaunchRoute(arguments: [String] = ProcessInfo.processInfo.arguments) -> Self {
        #if DEBUG
        guard arguments.contains("--coordit-ui-testing") else { return .main01 }
        guard
            let markerIndex = arguments.firstIndex(of: "--coordit-start-route"),
            arguments.indices.contains(arguments.index(after: markerIndex))
        else {
            return .main01
        }

        let routeValue = arguments[arguments.index(after: markerIndex)]
        return Self(rawValue: routeValue) ?? .main01
        #else
        return .main01
        #endif
    }

    var visibleIdentifier: String {
        switch self {
        case .main01:
            "main01-screen"
        case .main04, .fitLabInput, .closetOverview:
            "coordit-screen-\(rawValue)"
        case .splash,
             .fitLabLoading,
             .fitLabResultTop,
             .fitLabResultBottom,
             .fitLabHistoryRegister,
             .fitLabHistoryDetail,
             .myPage,
             .myPageThreadCharge,
             .myPageBody,
             .myPageAccount,
             .myPagePrivacy,
             .myPageAppSettings,
             .myPageNotifications,
             .closetDetailTop,
             .closetDetailBottom:
            "coordit-route-placeholder"
        }
    }

    var selectedTab: Main01Tab? {
        switch self {
        case .main01, .main04, .splash:
            .home
        case .fitLabInput,
             .fitLabLoading,
             .fitLabResultTop,
             .fitLabResultBottom,
             .fitLabHistoryRegister,
             .fitLabHistoryDetail:
            .fitLab
        case .closetOverview, .closetDetailTop, .closetDetailBottom:
            .closet
        case .myPage,
             .myPageThreadCharge,
             .myPageBody,
             .myPageAccount,
             .myPagePrivacy,
             .myPageAppSettings,
             .myPageNotifications:
            nil
        }
    }

    static func route(for tab: Main01Tab, from currentRoute: Self = .main04) -> Self {
        switch tab {
        case .home:
            currentRoute == .main01 ? .main01 : .main04
        case .fitLab:
            .fitLabInput
        case .closet:
            .closetOverview
        }
    }
}
#endif
