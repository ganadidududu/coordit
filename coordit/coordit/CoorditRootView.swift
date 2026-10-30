import SwiftUI

#if os(iOS)
struct CoorditRootView: View {
    @State private var route: CoorditFrameRoute
    @State private var navigationDirection: CoorditNavigationDirection = .forward
    @StateObject private var closetTutorial = CoorditClosetTutorial()
    @StateObject private var fitLabTutorial = CoorditFitLabTutorial()
    @StateObject private var firstUseGuidance = CoorditFirstUseGuidance()
    @State private var showsTutorialExitConfirmation = false
    @State private var tutorialExitDestination: CoorditFrameRoute?
    @State private var tutorialReturnRoute: CoorditFrameRoute?
    @State private var tutorialSavedSharedURL: URL?
    @State private var pendingPracticeSharedURL: URL?
    @State private var tutorialSavedClosetDraft: CoorditClosetDraft?
    @State private var tutorialSavedClosetItemID: String?
    @State private var tutorialSavedClosetSaveState: CoorditClosetAddSaveState?
    @State private var isPracticingReferenceRegistration = false
    @State private var closetItems: [CoorditClosetItem]
    @State private var selectedClosetItemID: String?
    @State private var closetDraft = CoorditClosetDraft()
    @State private var closetAddSaveState = CoorditClosetAddSaveState()
    @State private var isRegisteringFitLabReference = false
    @State private var selectedReferenceIDs: Set<String> = []
    @State private var showsFitLabReferenceSelection = false
    @State private var showsOnboarding = false
    @State private var threadBalance: Int
    @State private var showsThreadRechargePrompt = false
    @State private var showsInsufficientThreads = false
    @State private var sharedFitLabImportURL: URL?
    @State private var showsAuthenticationEntry = false
    @EnvironmentObject private var backendSession: CoorditBackendSessionStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var fitLabCoordinator: CoorditFitLabCoordinator

    init(startRoute: CoorditFrameRoute = .testingLaunchRoute()) {
        Self.seedPendingSharedFitLabImportURLIfNeeded()
        let initialSharedURL = Self.initialSharedFitLabImportURL()
        let initialRoute = initialSharedURL == nil ? startRoute : CoorditFrameRoute.fitLabInput
        _route = State(initialValue: initialRoute)
        _closetItems = State(initialValue: Self.initialClosetItems())
        _closetDraft = State(initialValue: Self.initialClosetDraft())
        _threadBalance = State(initialValue: Self.initialThreadBalance())
        _showsThreadRechargePrompt = State(
            initialValue: Self.initialThreadRechargePrompt(startRoute: startRoute)
        )
        _sharedFitLabImportURL = State(initialValue: initialSharedURL)
        _fitLabCoordinator = StateObject(
            wrappedValue: CoorditFitLabCoordinator.makeAppScoped(route: initialRoute)
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            if showsSharedAppBackground {
                CoorditSharedAppBackground()
                    .zIndex(-100)
            }

            Group {
                if blocksUnauthenticatedContent {
                    splashScreen
                } else {
                    switch route {
        case .main01:
            CoorditMain01Screen(initialTab: .home) { selectedTab in
                navigate(to: CoorditFrameRoute.route(for: selectedTab, from: route))
            }
        case .splash:
            splashScreen
        case .main04:
            CoorditMain04Screen(
                closetItems: $closetItems,
                selectedReferenceIDs: $selectedReferenceIDs,
                fitLabHistory: fitLabCoordinator.savedHistory,
                onOpenFitLabHistory: { snapshot in
                    fitLabCoordinator.selectHistory(snapshot)
                    navigate(to: .fitLabHistoryDetail)
                },
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
                        await backendSession.refreshReferenceFitProfiles()
                    }
                }
            ) { nextRoute in
                if nextRoute == .closetAddMethod {
                    startNewClosetRegistration()
                } else {
                    navigate(to: nextRoute)
                }
            }
        case .fitLabInput,
             .fitLabLoading,
             .fitLabResultTop,
             .fitLabResultBottom,
             .fitLabHistoryRegister,
             .fitLabHistoryDetail:
            CoorditFitLabFamilyView(
                currentRoute: route,
                onRouteChange: { navigate(to: $0) },
                onManageReferences: startFitLabReferenceRegistration,
                coordinator: fitLabCoordinator,
                threadBalance: $threadBalance,
                sharedImportURL: $sharedFitLabImportURL,
                onInsufficientThread: handleInsufficientThreadForFitLab,
                onOpenThreadRecharge: openThreadRechargeFromFitLab,
                onStartPractice: { beginFirstUsePractice(.fitLab) }
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
             .myPageTerms:
            CoorditMyPageFamilyView(
                route: route,
                threadBalance: $threadBalance,
                showsThreadRechargePrompt: $showsThreadRechargePrompt,
                onAccountDeleted: handleAccountDeletion
            ) { navigate(to: $0) }
        case .closetOverview,
             .closetDetailTop,
             .closetDetailBottom,
             .closetAddMethod,
             .closetAddLink,
             .closetAddPhoto,
             .closetAddSizeChart,
             .closetAddManual,
             .closetAddLoading,
             .closetAddResult:
            CoorditClosetFamilyView(
                route: route,
                items: $closetItems,
                selectedItemID: $selectedClosetItemID,
                draft: $closetDraft,
                selectedReferenceIDs: $selectedReferenceIDs,
                addSaveState: $closetAddSaveState,
                onSavedItem: routeAfterSavingClosetItem,
                referencePractice: isPracticingReferenceRegistration,
                onStartPractice: { beginFirstUsePractice(.closet) }
            ) { navigate(to: $0) }
                    }
                }
            }
            .environmentObject(closetTutorial)
            .environmentObject(fitLabTutorial)
            .coorditScreenTransition(value: route, direction: navigationDirection)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .environment(\.coorditShowsScreenChrome, false)
            .environment(\.coorditShowsScreenBackground, false)

            if showsScreenChrome {
                CoorditScreenChrome(
                    route: route,
                    onRouteChange: { navigate(to: $0) },
                    showsHeader: !fitLabCoordinator.isAnalysisNoticeVisible
                )
                    .zIndex(90)
            }

            if backendSession.isAuthenticated && !blocksUnauthenticatedContent {
                CoorditGlobalFitAnalysisBanner(
                    coordinator: fitLabCoordinator,
                    onOpenResult: { navigate(to: $0) },
                    onOpenFitLab: { navigate(to: .fitLabInput) }
                )
                .zIndex(100)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .buttonStyle(CoorditPressFeedbackButtonStyle())
        .task(id: firstUseVisitID) {
            let previousPractice = firstUseGuidance.activePractice
            firstUseGuidance.prepare(userID: firstUseGuidanceUserID)
            if previousPractice != nil, firstUseGuidance.activePractice == nil {
                fitLabTutorial.pause()
                closetTutorial.pause()
                tutorialReturnRoute = nil
                tutorialExitDestination = nil
                fitLabCoordinator.abandonTutorialPractice()
                tutorialSavedSharedURL = nil
                tutorialSavedClosetDraft = nil
                tutorialSavedClosetItemID = nil
                tutorialSavedClosetSaveState = nil
                isPracticingReferenceRegistration = false
            }
            startFirstUsePracticeIfNeeded()
        }
        .alert("실타래가 부족해요", isPresented: $showsInsufficientThreads) {
            Button("나중에", role: .cancel) { }
            Button("실타래 충전하기") { openThreadRechargeFromFitLab() }
        } message: {
            Text("상세 비교 리포트를 보려면 실타래 1개가 필요해요. 광고를 보고 무료로 충전할 수 있어요.")
        }
        .onChange(of: fitLabTutorial.completionRevision) { _, _ in finishFirstUsePractice(.fitLab) }
        .onChange(of: closetTutorial.completionRevision) { _, _ in
            if isPracticingReferenceRegistration { finishReferencePractice() }
            else { finishFirstUsePractice(.closet) }
        }
        .alert("처음이라면 끝까지 따라 해보는 걸 추천해요", isPresented: $showsTutorialExitConfirmation) {
            Button("계속 따라하기", role: .cancel) { tutorialExitDestination = nil }
            Button("이번에는 건너뛰기") {
                if firstUseGuidance.activePractice == .fitLab { fitLabTutorial.dismiss() }
                if firstUseGuidance.activePractice == .closet { closetTutorial.dismiss() }
            }
        } message: {
            Text("예시로 등록과 비교 흐름을 익힐 수 있어요. 나중에 사용법에서 다시 시작할 수도 있어요.")
        }
        .task(id: backendSession.isAuthenticated) {
            if backendSession.isAuthenticated {
                showsAuthenticationEntry = false
                return
            }

            guard !permitsUnauthenticatedUITestRoute else { return }
            showsAuthenticationEntry = false
            threadBalance = 0
            showsFitLabReferenceSelection = false
            showsThreadRechargePrompt = false

            if route != .splash {
                navigate(to: .splash)
            }
        }
        .task(id: backendSession.session?.user.id) {
            await backendSession.bootstrap()
            if backendSession.isAuthenticated, !backendSession.canUseProduct {
                return
            }
            guard canShowSelectedRoute else {
                presentOnboardingIfNeeded()
                return
            }
            if let snapshot = await backendSession.loadClosetSnapshot(preserving: closetItems) {
                closetItems = snapshot.items
                selectedReferenceIDs = snapshot.selectedReferenceIDs
            }
            if let balance = await backendSession.fetchThreadBalance() {
                threadBalance = balance
            }
        }
        .task(id: fitLabHistoryUserID) {
            await fitLabCoordinator.prepareHistory(userID: fitLabHistoryUserID)
        }
        #if DEBUG
        .task {
            await performTestingAutoNavigationIfNeeded()
        }
        #endif
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
        .onReceive(NotificationCenter.default.publisher(for: CoorditSharedFitLabImport.didRequestOpenNotification)) { notification in
            openSharedFitLabImport(notification.object as? URL)
        }
        .onChange(of: fitLabCoordinator.cameraMeasurement) { _, measurement in
            guard let measurement, measurement.id == fitLabCoordinator.cameraCapture.identifier,
                  let receipt = fitLabCoordinator.cameraReference else { return }
            let backendID = receipt.reference.clothingItemID
            let photo = fitLabCoordinator.cameraCapture.garmentPhotoData
            let chart = CoorditClosetSizeChart(sizeLabel: nil, measurements: measurement.clothingSizeRequest.measurements)
            if let index = closetItems.firstIndex(where: { $0.backendClothingItemId == backendID }) {
                if let photo { closetItems[index].imageData = photo }
                closetItems[index].sizeChart = chart
                closetItems[index].backendReferenceClothingId = receipt.reference.id
            } else {
                closetItems.insert(CoorditClosetItem(
                    id: backendID,
                    name: measurement.garmentName,
                    category: measurement.isLower ? .bottom : .top,
                    exactCategory: measurement.resolvedCategory,
                    score: 0,
                    scoreColor: CoorditClosetColors.navy,
                    route: measurement.isLower ? .closetDetailBottom : .closetDetailTop,
                    imageData: photo,
                    sizeChart: chart,
                    backendClothingItemId: backendID,
                    backendReferenceClothingId: receipt.reference.id
                ), at: 0)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            openPendingSharedFitLabImport()
            Task {
                await backendSession.refreshPersistedSessionIfNeeded()
            }
        }
        .task {
            await backendSession.restorePersistedSession()
            openPendingSharedFitLabImport()
        }
        .sheet(isPresented: $showsFitLabReferenceSelection) {
            CoorditHomeReferenceSelectionSheet(
                items: closetItems,
                initialSelection: selectedReferenceIDs,
                onCommit: syncFitLabReferenceSelection,
                onAddGarment: startFitLabReferenceRegistration
            )
        }
        .sheet(isPresented: $showsAuthenticationEntry) {
            CoorditSplashAuthenticationSheet(
                onAuthenticated: {
                    showsAuthenticationEntry = false
                    if backendSession.onboardingComplete {
                        CoorditWelcomeLaunchState.markWelcomeCompleted()
                        navigate(to: .main04)
                    } else {
                        showsOnboarding = true
                    }
                },
                onGuestAuthenticated: { balance in
                    threadBalance = balance
                    CoorditWelcomeLaunchState.markWelcomeCompleted()
                    showsAuthenticationEntry = false
                    navigate(to: .main04)
                }
            )
        }
        .fullScreenCover(isPresented: $showsOnboarding) {
            CoorditOnboardingView {
                guard backendSession.canUseProduct else {
                    showsOnboarding = false
                    return true
                }
                guard let balance = await backendSession.fetchThreadBalance() else {
                    return false
                }
                threadBalance = balance
                showsOnboarding = false
                CoorditWelcomeLaunchState.markWelcomeCompleted()
                navigate(to: .main04)
                return true
            }
        }
    }

    private var firstUseGuidanceUserID: String? {
        guard backendSession.isAuthenticated, backendSession.canUseProduct, route != .splash,
              !showsOnboarding, !showsAuthenticationEntry else { return nil }
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--coordit-ui-testing") {
            guard arguments.contains("--coordit-test-first-use-guides") else { return nil }
            if let index = arguments.firstIndex(of: "--coordit-tutorial-account"), arguments.indices.contains(index + 1) {
                return arguments[index + 1]
            }
        }
        #endif
        return backendSession.session?.user.id
    }

    private var firstUseVisitID: String {
        "\(firstUseGuidanceUserID ?? "signed-out").\(route.rawValue)"
    }

    private func startFirstUsePracticeIfNeeded() {
        guard firstUseGuidanceUserID != nil, firstUseGuidance.activePractice == nil,
              !isPracticingReferenceRegistration else { return }
        if route == .fitLabInput, !fitLabCoordinator.isAnalysisRunning,
           fitLabCoordinator.retryStep == nil, fitLabCoordinator.recommendation == nil,
           firstUseGuidance.needsPractice(.fitLab) {
            beginFirstUsePractice(.fitLab)
        } else if route.navigationSection == 2, !closetAddSaveState.isSaving,
                  firstUseGuidance.needsPractice(.closet) {
            beginFirstUsePractice(.closet)
        }
    }

    private func beginFirstUsePractice(_ guide: CoorditUsageGuide) {
        guard firstUseGuidance.activePractice == nil else { return }
        if guide == .fitLab || guide == .fitLabReferences {
            guard fitLabCoordinator.beginTutorialPractice() else { return }
        }
        if tutorialReturnRoute == nil { tutorialReturnRoute = route }
        firstUseGuidance.begin(guide)
        switch guide {
        case .fitLab, .fitLabReferences:
            tutorialSavedSharedURL = sharedFitLabImportURL
            sharedFitLabImportURL = nil
            fitLabTutorial.requiresSkipConfirmation = true
            fitLabTutorial.restart()
            fitLabTutorial.show(.link)
            navigate(to: .fitLabInput)
        case .closet:
            tutorialSavedClosetDraft = closetDraft
            tutorialSavedClosetItemID = selectedClosetItemID
            tutorialSavedClosetSaveState = closetAddSaveState
            selectedClosetItemID = nil
            closetDraft = CoorditClosetDraft()
            closetDraft.method = .link
            closetDraft.productLink = CoorditTutorialExample.link
            closetAddSaveState.reset()
            closetTutorial.requiresSkipConfirmation = true
            closetTutorial.restart()
            closetTutorial.advance(from: .add, to: .method)
            closetTutorial.updateLink(closetDraft.productLink)
            navigate(to: .closetAddLink)
        }
    }

    private func finishFirstUsePractice(_ guide: CoorditUsageGuide) {
        guard firstUseGuidance.activePractice == guide else { return }
        firstUseGuidance.finish(guide)
        switch guide {
        case .fitLab, .fitLabReferences:
            if isPracticingReferenceRegistration {
                firstUseGuidance.markCompleted(.closet)
                closetTutorial.pause()
                closetTutorial.requiresSkipConfirmation = false
                restoreClosetAfterPractice()
                isPracticingReferenceRegistration = false
            }
            fitLabTutorial.requiresSkipConfirmation = false
            fitLabCoordinator.finishTutorialPractice()
            sharedFitLabImportURL = tutorialSavedSharedURL
            tutorialSavedSharedURL = nil
        case .closet:
            closetTutorial.requiresSkipConfirmation = false
            restoreClosetAfterPractice()
        }
        if let pending = pendingPracticeSharedURL {
            pendingPracticeSharedURL = nil
            tutorialReturnRoute = nil
            tutorialExitDestination = nil
            openSharedFitLabImport(pending)
            return
        }
        returnAfterFirstUseIfFinished()
    }

    private func returnAfterFirstUseIfFinished() {
        if firstUseGuidance.activePractice == nil, let destination = tutorialExitDestination ?? tutorialReturnRoute {
            tutorialReturnRoute = nil
            tutorialExitDestination = nil
            navigate(to: destination)
        }
    }

    private func navigate(to nextRoute: CoorditFrameRoute) {
        if let practice = firstUseGuidance.activePractice, nextRoute != .splash {
            let section = practice == .closet ? 2 : 1
            let isReferenceStep = practice == .fitLab && isPracticingReferenceRegistration && nextRoute.navigationSection == 2
            let leavesReferencePractice = isPracticingReferenceRegistration && nextRoute.navigationSection != 2
            let leavesClosetStep = (practice == .closet || isPracticingReferenceRegistration)
                && [.closetAddMethod, .closetOverview].contains(nextRoute) && closetTutorial.step != nil
            if leavesReferencePractice || (!isReferenceStep && nextRoute.navigationSection != section) || leavesClosetStep {
                tutorialExitDestination = nextRoute
                showsTutorialExitConfirmation = true
                return
            }
        }
        if isRegisteringFitLabReference, nextRoute == .closetOverview {
            isRegisteringFitLabReference = false
        }
        guard nextRoute == .splash || canShowSelectedRoute else {
            route = .splash
            return
        }
        let destination = nextRoute == .fitLabInput && fitLabCoordinator.isAnalysisRunning
            ? CoorditFrameRoute.fitLabLoading
            : nextRoute
        guard destination != route else { return }
        if destination.navigationSection == route.navigationSection {
            navigationDirection = destination.navigationDepth >= route.navigationDepth ? .forward : .backward
        } else if destination.navigationSection == 0 {
            navigationDirection = .backward
        } else {
            navigationDirection = .forward
        }
        withAnimation(CoorditMotion.navigation(reduceMotion: reduceMotion)) {
            route = destination
        }
    }

    private func restoreClosetAfterPractice() {
        if let draft = tutorialSavedClosetDraft { closetDraft = draft }
        selectedClosetItemID = tutorialSavedClosetItemID
        if let saveState = tutorialSavedClosetSaveState { closetAddSaveState = saveState }
        tutorialSavedClosetDraft = nil
        tutorialSavedClosetItemID = nil
        tutorialSavedClosetSaveState = nil
    }

    private func finishReferencePractice() {
        let completed = closetTutorial.completedRegistration
        closetTutorial.requiresSkipConfirmation = false
        restoreClosetAfterPractice()
        isPracticingReferenceRegistration = false
        firstUseGuidance.markCompleted(.closet)
        if completed { fitLabCoordinator.registerTutorialReference() }
        navigate(to: .fitLabInput)
    }

    private func startNewClosetRegistration() {
        isRegisteringFitLabReference = false
        closetDraft = CoorditClosetDraft()
        closetAddSaveState.reset()
        navigate(to: .closetAddMethod)
    }

    private func startFitLabReferenceRegistration() {
        if isPracticingReferenceRegistration { navigate(to: .closetAddLink); return }
        if fitLabCoordinator.draft.isTutorialExample {
            tutorialSavedClosetDraft = closetDraft
            tutorialSavedClosetItemID = selectedClosetItemID
            tutorialSavedClosetSaveState = closetAddSaveState
            selectedClosetItemID = nil
            closetDraft = CoorditClosetDraft()
            closetDraft.method = .link
            closetDraft.productLink = CoorditTutorialExample.link
            closetDraft.exactCategory = fitLabCoordinator.draft.category
            closetDraft.category = fitLabCoordinator.draft.category.garmentKind == .upper ? .top : .bottom
            closetAddSaveState.reset()
            isPracticingReferenceRegistration = true
            closetTutorial.requiresSkipConfirmation = true
            closetTutorial.restart()
            closetTutorial.advance(from: .add, to: .method)
            closetTutorial.updateLink(closetDraft.productLink)
            navigate(to: .closetAddLink)
            return
        }
        isRegisteringFitLabReference = true
        closetDraft = CoorditClosetDraft()
        closetDraft.category = fitLabCoordinator.draft.category.garmentKind == .upper ? .top : .bottom
        closetDraft.exactCategory = fitLabCoordinator.draft.category
        closetDraft.method = .link
        closetAddSaveState.reset()
        navigate(to: .closetAddLink)
    }

    private static func initialClosetItems(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> [CoorditClosetItem] {
        #if DEBUG
        if arguments.contains("--coordit-ui-testing"),
           !arguments.contains("--coordit-empty-closet") {
            return CoorditClosetItem.seedItems
        }
        #endif
        return []
    }

    private static func initialClosetDraft(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> CoorditClosetDraft {
        #if DEBUG
        if arguments.contains("--coordit-test-prefilled-closet-draft") {
            var draft = CoorditClosetDraft()
            draft.method = .link
            draft.productLink = "https://shop.example/products/previous-item"
            return draft
        }
        #endif
        return CoorditClosetDraft()
    }

    private static func initialThreadBalance(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Int {
        #if DEBUG
        if arguments.contains("--coordit-ui-testing"),
           let markerIndex = arguments.firstIndex(of: "--coordit-thread-balance"),
           arguments.indices.contains(arguments.index(after: markerIndex)),
           let value = Int(arguments[arguments.index(after: markerIndex)]) {
            return max(0, value)
        }
        #endif
        return 0
    }

    private static func initialThreadRechargePrompt(
        startRoute: CoorditFrameRoute,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Bool {
        #if DEBUG
        arguments.contains("--coordit-ui-testing")
            && arguments.contains("--coordit-thread-recharge-prompt")
            && startRoute == .myPageThreadCharge
        #else
        false
        #endif
    }

    private static func initialSharedFitLabImportURL(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> URL? {
        #if DEBUG
        guard arguments.contains("--coordit-ui-testing"),
              let markerIndex = arguments.firstIndex(of: "--coordit-shared-fitlab-url"),
              arguments.indices.contains(arguments.index(after: markerIndex)),
              let url = URL(string: arguments[arguments.index(after: markerIndex)]),
              url.isHTTPOrHTTPSProductURL
        else { return nil }
        return url
        #else
        return nil
        #endif
    }

    private static func seedPendingSharedFitLabImportURLIfNeeded(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) {
        #if DEBUG
        guard arguments.contains("--coordit-ui-testing"),
              let markerIndex = arguments.firstIndex(of: "--coordit-pending-fitlab-url"),
              arguments.indices.contains(arguments.index(after: markerIndex)),
              let url = URL(string: arguments[arguments.index(after: markerIndex)]),
              url.isHTTPOrHTTPSProductURL
        else { return }
        CoorditSharedFitLabImport.store(productURL: url, sourceApplication: "ui-test")
        #endif
    }

    private var blocksUnauthenticatedContent: Bool {
        !backendSession.isAuthenticated
            && route != .splash
            && !permitsUnauthenticatedUITestRoute
    }

    private var permitsUnauthenticatedUITestRoute: Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--coordit-ui-testing"),
              !arguments.contains("--coordit-enforce-auth-gate"),
              let markerIndex = arguments.firstIndex(of: "--coordit-start-route"),
              arguments.indices.contains(arguments.index(after: markerIndex))
        else { return false }

        return arguments[arguments.index(after: markerIndex)] != CoorditFrameRoute.splash.rawValue
        #else
        false
        #endif
    }

    private var showsScreenChrome: Bool {
        !blocksUnauthenticatedContent && route != .splash && route != .main01
    }

    private var splashPresentation: CoorditSplashPresentation {
        CoorditWelcomeLaunchState.splashPresentation(isAuthenticated: backendSession.isAuthenticated)
    }

    private var splashScreen: some View {
        CoorditSplashScreen(
            presentation: splashPresentation,
            onRouteChange: { nextRoute in
                guard backendSession.canUseProduct else {
                    presentOnboardingIfNeeded()
                    return
                }
                navigate(to: nextRoute)
            },
            onAuthenticationRequested: { showsAuthenticationEntry = true }
        )
    }

    private var canShowSelectedRoute: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--coordit-ui-testing") {
            return true
        }
        #endif
        return route == .splash || backendSession.canUseProduct
    }

    private func presentOnboardingIfNeeded() {
        guard backendSession.isMember, !backendSession.onboardingComplete else { return }
        showsOnboarding = true
    }

    private var showsSharedAppBackground: Bool {
        !blocksUnauthenticatedContent && route != .splash && route != .main01
    }

    private var fitLabHistoryUserID: String? {
        #if DEBUG
        if fitLabCoordinator.fixtureName != nil {
            return fitLabCoordinator.userID
        }
        #endif
        return backendSession.session?.user.id
    }

    private func syncFitLabReferenceSelection(_ selection: Set<String>) {
        Task {
            _ = await persistFitLabReferenceSelection(selection)
        }
    }

    private func routeAfterSavingClosetItem(_ item: CoorditClosetItem) async -> CoorditFrameRoute? {
        guard isRegisteringFitLabReference else { return nil }
        defer { isRegisteringFitLabReference = false }

        let selection = selectedReferenceIDs.union([item.id])
        guard let result = await persistFitLabReferenceSelection(selection),
              let referenceID = result.referenceIDsByItemID[item.id],
              fitLabCoordinator.selectReference(id: referenceID)
        else { return nil }

        fitLabCoordinator.isComparisonRequested = true
        return .fitLabInput
    }

    private func persistFitLabReferenceSelection(
        _ selection: Set<String>
    ) async -> CoorditReferenceSyncResult? {
        guard let result = await backendSession.syncReferenceSelection(
            items: closetItems,
            selectedIDs: selection
        ) else { return nil }
        for index in closetItems.indices {
            if let referenceID = result.referenceIDsByItemID[closetItems[index].id] {
                closetItems[index].backendReferenceClothingId = referenceID
            }
        }
        selectedReferenceIDs = result.selectedIDs
        await backendSession.refreshReferenceFitProfiles()
        await reloadFitLabReferences()
        return result
    }

    private func reloadFitLabReferences() async {
        fitLabCoordinator.configureLandmarkGateway(using: backendSession.session.map {
            CoorditFitLabHTTPAPI(baseURL: CoorditBackendConfig.baseURL(), accessToken: $0.accessToken)
        })
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

    private func handleInsufficientThreadForFitLab() {
        showsInsufficientThreads = true
    }

    private func openThreadRechargeFromFitLab() {
        showsThreadRechargePrompt = false
        navigate(to: .myPageThreadCharge)
    }

    private func handleAccountDeletion(userID: String) async -> Bool {
        do { try CoorditGarmentPhotoStore.shared.removeAll(userID: userID) }
        catch { return false }
        closetItems = []
        selectedClosetItemID = nil
        closetDraft = CoorditClosetDraft()
        closetAddSaveState.reset()
        selectedReferenceIDs = []
        threadBalance = 0
        showsThreadRechargePrompt = false
        sharedFitLabImportURL = nil
        fitLabCoordinator.discardAndRestart()
        return await fitLabCoordinator.deleteLocalHistory(for: userID)
    }

    private func openPendingSharedFitLabImport() {
        guard let url = CoorditSharedFitLabImport.consumePendingProductURL() else { return }
        openSharedFitLabImport(url)
    }

    private func openSharedFitLabImport(_ url: URL?) {
        guard let url else { return }
        // A direct URL notification may arrive before scene activation. Remove
        // its queued copy so activation cannot reset the in-progress Fit Lab flow.
        CoorditSharedFitLabImport.removePendingProductURL(matching: url)
        if firstUseGuidance.activePractice != nil {
            pendingPracticeSharedURL = url
            return
        }
        fitLabCoordinator.discardAndRestart()
        sharedFitLabImportURL = url
        navigate(to: .fitLabInput)
    }

    #if DEBUG
    private func performTestingAutoNavigationIfNeeded(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) async {
        guard arguments.contains("--coordit-ui-testing"),
              let markerIndex = arguments.firstIndex(of: "--coordit-auto-route"),
              arguments.indices.contains(arguments.index(after: markerIndex)),
              let nextRoute = CoorditFrameRoute(
                rawValue: arguments[arguments.index(after: markerIndex)]
              ) else {
            return
        }

        try? await Task.sleep(for: .seconds(1))
        guard !Task.isCancelled else { return }
        navigate(to: nextRoute)
    }
    #endif
}
#endif
