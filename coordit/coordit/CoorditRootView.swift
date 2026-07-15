import SwiftUI

#if os(iOS)
struct CoorditRootView: View {
    @State private var route: CoorditFrameRoute
    @State private var closetItems = CoorditClosetItem.seedItems
    @State private var selectedClosetItemID: String?
    @State private var closetDraft = CoorditClosetDraft()

    init(startRoute: CoorditFrameRoute = .testingLaunchRoute()) {
        _route = State(initialValue: startRoute)
    }

    var body: some View {
        switch route {
        case .main01:
            CoorditMain01Screen(initialTab: .home) { selectedTab in
                route = CoorditFrameRoute.route(for: selectedTab, from: route)
            }
        case .splash:
            CoorditSplashScreen { route = $0 }
        case .main04:
            CoorditMain04Screen { route = $0 }
        case .fitLabInput,
             .fitLabLoading,
             .fitLabResultTop,
             .fitLabResultBottom,
             .fitLabHistoryRegister,
             .fitLabHistoryDetail:
            CoorditFitLabFamilyView(currentRoute: route) { route = $0 }
        case .myPage,
             .myPageThreadCharge,
             .myPageBody,
             .myPageAccount,
             .myPagePrivacy,
             .myPageAppSettings,
             .myPageNotifications,
             .myPageProfileEdit,
             .myPagePasswordChange,
             .myPageLogout,
             .myPageAccountDeletion,
             .myPageBodyMeasurements,
             .myPagePrivacyPolicy,
             .myPageTerms,
             .myPageContact,
             .myPageBugReport:
            CoorditMyPageFamilyView(route: route) { route = $0 }
        case .closetOverview,
             .closetDetailTop,
             .closetDetailBottom,
             .closetAddMethod,
             .closetAddLink,
             .closetAddPhoto,
             .closetAddManual,
             .closetAddLoading,
             .closetAddResult:
            CoorditClosetFamilyView(
                route: route,
                items: $closetItems,
                selectedItemID: $selectedClosetItemID,
                draft: $closetDraft
            ) { route = $0 }
        }
    }
}
#endif
