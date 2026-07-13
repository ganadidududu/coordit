import Foundation

#if os(iOS)
struct CoorditRouteContent {
    let eyebrow: String
    let title: String
    let detail: String
}

enum CoorditMockData {
    static func content(for route: CoorditFrameRoute) -> CoorditRouteContent {
        switch route {
        case .main01:
            CoorditRouteContent(eyebrow: "HOME", title: "Main 01", detail: route.rawValue)
        case .splash:
            CoorditRouteContent(eyebrow: "START", title: "Splash", detail: route.rawValue)
        case .main04:
            CoorditRouteContent(eyebrow: "HOME", title: "Today Coordination", detail: route.rawValue)
        case .fitLabInput:
            CoorditRouteContent(eyebrow: "FIT LAB", title: "Fit Lab Input", detail: route.rawValue)
        case .fitLabLoading:
            CoorditRouteContent(eyebrow: "FIT LAB", title: "Analyzing Fit", detail: route.rawValue)
        case .fitLabResultTop:
            CoorditRouteContent(eyebrow: "FIT LAB", title: "Top Fit Result", detail: route.rawValue)
        case .fitLabResultBottom:
            CoorditRouteContent(eyebrow: "FIT LAB", title: "Bottom Fit Result", detail: route.rawValue)
        case .fitLabHistoryRegister:
            CoorditRouteContent(eyebrow: "FIT LAB", title: "Register History", detail: route.rawValue)
        case .fitLabHistoryDetail:
            CoorditRouteContent(eyebrow: "FIT LAB", title: "History Detail", detail: route.rawValue)
        case .myPage:
            CoorditRouteContent(eyebrow: "MY", title: "My Page", detail: route.rawValue)
        case .myPageThreadCharge:
            CoorditRouteContent(eyebrow: "MY", title: "Thread Charge", detail: route.rawValue)
        case .myPageBody:
            CoorditRouteContent(eyebrow: "MY", title: "Body Profile", detail: route.rawValue)
        case .myPageAccount:
            CoorditRouteContent(eyebrow: "MY", title: "Account", detail: route.rawValue)
        case .myPagePrivacy:
            CoorditRouteContent(eyebrow: "MY", title: "Privacy", detail: route.rawValue)
        case .myPageAppSettings:
            CoorditRouteContent(eyebrow: "MY", title: "App Settings", detail: route.rawValue)
        case .myPageNotifications:
            CoorditRouteContent(eyebrow: "MY", title: "Notifications", detail: route.rawValue)
        case .closetOverview:
            CoorditRouteContent(eyebrow: "CLOSET", title: "Closet Overview", detail: route.rawValue)
        case .closetDetailTop:
            CoorditRouteContent(eyebrow: "CLOSET", title: "Top Detail", detail: route.rawValue)
        case .closetDetailBottom:
            CoorditRouteContent(eyebrow: "CLOSET", title: "Bottom Detail", detail: route.rawValue)
        }
    }
}
#endif
