import SwiftUI

#if os(iOS)
struct CoorditRootView: View {
    @State private var route: CoorditFrameRoute
    @State private var closetItems = CoorditClosetItem.seedItems
    @State private var selectedClosetItemID: String?
    @State private var closetDraft = CoorditClosetDraft()
    @State private var selectedReferenceIDs: Set<String> = []
    @State private var showsFitLabReferenceSelection = false
    @EnvironmentObject private var backendSession: CoorditBackendSessionStore
    @StateObject private var fitLabCoordinator: CoorditFitLabCoordinator

    init(startRoute: CoorditFrameRoute = .testingLaunchRoute()) {
        _route = State(initialValue: startRoute)
        _fitLabCoordinator = StateObject(
            wrappedValue: CoorditFitLabCoordinator.makeAppScoped(route: startRoute)
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                switch route {
        case .main01:
            CoorditMain01Screen(initialTab: .home) { selectedTab in
                route = CoorditFrameRoute.route(for: selectedTab, from: route)
            }
        case .splash:
            CoorditSplashScreen { route = $0 }
        case .main04:
            CoorditMain04Screen(
                closetItems: $closetItems,
                selectedReferenceIDs: $selectedReferenceIDs,
                onReferenceCommit: { selection in
                    Task {
                        guard let result = await backendSession.syncReferenceSelection(
                            items: closetItems,
                            selectedIDs: selection
                        ) else { return }
                        for index in closetItems.indices {
                            if let referenceID = result.referenceIDsByItemID[closetItems[index].id] {
                                closetItems[index].backendReferenceClothingId = referenceID
                            }
                        }
                        selectedReferenceIDs = result.selectedIDs
                    }
                }
            ) { route = $0 }
        case .fitLabInput,
             .fitLabLoading,
             .fitLabResultTop,
             .fitLabResultBottom,
             .fitLabHistoryRegister,
             .fitLabHistoryDetail:
            CoorditFitLabFamilyView(
                currentRoute: route,
                onRouteChange: { route = $0 },
                onManageReferences: { showsFitLabReferenceSelection = true },
                coordinator: fitLabCoordinator
            )
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            CoorditGlobalFitAnalysisBanner(
                coordinator: fitLabCoordinator,
                onOpenResult: { route = $0 },
                onOpenFitLab: { route = .fitLabInput }
            )
            .zIndex(100)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: backendSession.session?.user.id) {
            guard let snapshot = await backendSession.loadClosetSnapshot(preserving: closetItems) else { return }
            closetItems = snapshot.items
            selectedReferenceIDs = snapshot.selectedReferenceIDs
        }
        .onChange(of: closetItems.compactMap(\.backendReferenceClothingId)) { oldIDs, newIDs in
            let addedReferenceIDs = Set(newIDs).subtracting(oldIDs)
            guard !addedReferenceIDs.isEmpty else { return }
            selectedReferenceIDs.formUnion(
                closetItems.compactMap { item in
                    guard let referenceID = item.backendReferenceClothingId,
                          addedReferenceIDs.contains(referenceID) else { return nil }
                    return item.id
                }
            )
        }
        .sheet(isPresented: $showsFitLabReferenceSelection) {
            CoorditHomeReferenceSelectionSheet(
                items: closetItems,
                initialSelection: selectedReferenceIDs,
                onCommit: syncFitLabReferenceSelection,
                onAddGarment: { route = .closetAddMethod }
            )
        }
    }

    private func syncFitLabReferenceSelection(_ selection: Set<String>) {
        Task {
            guard let result = await backendSession.syncReferenceSelection(
                items: closetItems,
                selectedIDs: selection
            ) else { return }
            for index in closetItems.indices {
                if let referenceID = result.referenceIDsByItemID[closetItems[index].id] {
                    closetItems[index].backendReferenceClothingId = referenceID
                }
            }
            selectedReferenceIDs = result.selectedIDs

            #if DEBUG
            if fitLabCoordinator.fixtureName != nil {
                await fitLabCoordinator.loadCompatibleReferences()
                return
            }
            #endif
            guard let session = backendSession.session else {
                await fitLabCoordinator.loadCompatibleReferences(authenticatedUserID: nil)
                return
            }
            let api = CoorditFitLabHTTPAPI(
                baseURL: CoorditBackendConfig.baseURL(),
                accessToken: session.accessToken
            )
            await fitLabCoordinator.loadCompatibleReferences(
                using: api,
                authenticatedUserID: session.user.id
            )
        }
    }
}
#endif
