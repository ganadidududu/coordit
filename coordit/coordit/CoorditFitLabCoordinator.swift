import Foundation
import Combine
import CryptoKit

#if os(iOS)
enum CoorditFitLabAnalysisState: Equatable {
    case idle
    case running
    case completed(CoorditFrameRoute)
    case failed(String)
}

@MainActor
final class CoorditFitLabCoordinator: ObservableObject {
    private struct PendingSubmissionKey: Codable {
        let fingerprint: String
        let idempotencyKey: String
    }

    private struct SubmissionFingerprint: Codable {
        let userID: String
        let source: CoorditFitLabSource
        let category: CoorditFitLabCategory
        let productName: String
        let productURL: URL?
        let sizes: [CoorditFitLabSizeDraft]
        let referenceIDs: [String]
    }

    @Published var draft: CoorditFitLabDraft
    @Published var isComparisonRequested = false
    @Published private(set) var references: [CoorditFitLabReferenceRow] = []
    @Published private(set) var createdProductID: String?
    @Published private(set) var createdSizeIDs: [String] = []
    @Published private(set) var checkpoint = CoorditFitLabSubmissionCheckpoint()
    @Published private(set) var recommendation: CoorditFitLabRecommendationResponse?
    @Published private(set) var report: CoorditFitLabReportResponse?
    @Published private(set) var reportFailureMessage: String?
    @Published var selectedHistory: CoorditFitLabHistorySnapshot?
    @Published private(set) var savedHistory: [CoorditFitLabHistorySnapshot] = []
    @Published private(set) var historyRecoveryNotice: String?
    @Published private(set) var activeHistoryUserID: String?
    @Published private(set) var error: CoorditFitLabError?
    @Published private(set) var retryStep: CoorditFitLabSubmissionStep?
    @Published private(set) var submissionStep: CoorditFitLabSubmissionStep = .idle
    @Published private(set) var loadState: CoorditFitLabLoadState = .idle
    @Published private(set) var screen: CoorditFitLabScreen
    @Published private(set) var analysisState: CoorditFitLabAnalysisState = .idle
    @Published private(set) var isAnalysisNoticeVisible = false
    @Published private(set) var authoritativeThreadBalance: Int?
    @Published private(set) var cameraMeasurement: CoorditGarmentMeasurement?
    @Published private(set) var cameraReference: CoorditCameraReference?
    @Published private(set) var cameraBundleAnalysisID: String?
    private var cameraSessionUserID: String?
    private var isPreparingCameraAnalysis = false
    let cameraCapture = CoorditGarmentCaptureController()
    @Published private(set) var landmarkGateway: CoorditRemoteLandmarkProvider?

    func configureLandmarkGateway(using api: CoorditFitLabHTTPAPI?) {
        guard let api, CoorditRemoteLandmarkProvider.enabled else {
            if landmarkGateway != nil { cameraCapture.cancelInference() }
            landmarkGateway = nil; return
        }
        if landmarkGateway?.bearerToken != api.accessToken { cameraCapture.cancelInference() }
        landmarkGateway = CoorditRemoteLandmarkProvider(endpoint: api.baseURL.appending(path: "garment-landmarks"),
            bearerToken: api.accessToken, processingConsent: true,
            allowDevelopmentProposals: CoorditRemoteLandmarkProvider.developmentEnabled)
    }

    let userID: String?
    let fixtureName: String?
    private let api: (any CoorditFitLabAPI)?
    private let historyStore: (any CoorditFitLabHistoryStoring)?
    #if DEBUG
    private(set) var fixtureAPI: CoorditFitLabFixtureAPI?
    #endif
    private var operationGeneration = 0
    private var submissionTask: Task<Void, Never>?
    private var historyGeneration = 0
    private var historyMutationTask: Task<Bool, Never>?
    private var historyMutationGeneration = 0
    private static let pendingIdempotencyKeyDefaultsKey = "coordit.fitLab.pendingIdempotencyKey.v1"
    #if DEBUG
    @Published private(set) var historyEdgeProbe = "idle"
    @Published private(set) var historyUserProbe = "idle"
    @Published private(set) var historyStoreAudit = "idle"
    @Published private(set) var historyRaceProbe = "idle"
    @Published private(set) var historyF2Probe = "idle"
    @Published private(set) var historyQuarantineCount = 0
    #endif

    init(
        route: CoorditFrameRoute,
        configuration: CoorditFitLabFixtureConfiguration,
        api: (any CoorditFitLabAPI)? = nil,
        historyStore: (any CoorditFitLabHistoryStoring)? = nil
    ) {
        self.userID = configuration.userID
        self.fixtureName = configuration.name
        self.api = api
        self.historyStore = historyStore
        self.activeHistoryUserID = configuration.userID
        #if DEBUG
        self.fixtureAPI = api as? CoorditFitLabFixtureAPI
        #endif
        self.draft = CoorditFitLabDraft()
        self.screen = Self.screen(for: route)
        #if DEBUG
        if configuration.name != nil {
            if configuration.name?.hasPrefix("submission-") == true {
                self.draft = CoorditFitLabFixtures.submissionDraft
            } else {
                self.draft = CoorditFitLabFixtures.upperDraft
            }
            seed(route: route, fixture: configuration.name)
        }
        let launchArguments = ProcessInfo.processInfo.arguments
        if launchArguments.contains("--coordit-test-analysis-running-then-completed") {
            analysisState = .running
            isAnalysisNoticeVisible = true
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled else { return }
                self?.analysisState = .completed(.fitLabResultTop)
                self?.isAnalysisNoticeVisible = true
            }
        } else if launchArguments.contains("--coordit-test-analysis-running") {
            analysisState = .running
            isAnalysisNoticeVisible = true
        } else if launchArguments.contains("--coordit-test-analysis-completed") {
            analysisState = .completed(.fitLabResultTop)
            isAnalysisNoticeVisible = true
        }
        #endif
    }

    static func makeAppScoped(route: CoorditFrameRoute) -> CoorditFitLabCoordinator {
        let configuration = CoorditFitLabFixtureConfiguration.launch()
        #if DEBUG
        if configuration.name != nil {
            if configuration.resetsHistory, let directory = configuration.historyRootDirectory {
                CoorditFitLabHistoryFixtureResetRegistry.resetOnce(directory)
            }
            let historyStore: any CoorditFitLabHistoryStoring
            if let directory = configuration.historyRootDirectory {
                historyStore = CoorditFitLabFileHistoryStore(rootDirectory: directory)
            } else {
                historyStore = CoorditFitLabFixtureHistoryStore()
            }
            return CoorditFitLabCoordinator(
                route: route,
                configuration: configuration,
                api: CoorditFitLabFixtureAPI(fixtureName: configuration.name),
                historyStore: historyStore
            )
        }
        #endif
        return CoorditFitLabCoordinator(
            route: route,
            configuration: configuration,
            historyStore: CoorditFitLabFileHistoryStore.shared
        )
    }

    var isAnalysisRunning: Bool {
        if case .running = analysisState { return true }
        return false
    }

    func analyzeCameraMeasurement(
        _ measurement: CoorditGarmentMeasurement,
        using overrideAPI: (any CoorditFitLabAPI)? = nil,
        authenticatedUserID: String? = nil
    ) async throws {
        guard CoorditGarmentCaptureController.featureEnabled else { throw CoorditFitLabError.invalidDraft("카메라 비교 기능을 준비하고 있어요.") }
        guard !isPreparingCameraAnalysis, !isAnalysisRunning, loadState != .loading else { throw CoorditFitLabError.invalidDraft("현재 분석을 마친 뒤 다시 시도해주세요.") }
        guard let owner = authenticatedUserID ?? userID else { throw CoorditFitLabError.loginRequired }
        guard let selectedAPI = overrideAPI ?? api else { throw CoorditFitLabError.transport("분석 연결을 준비하지 못했어요.") }
        guard draft.category == measurement.resolvedCategory, !draft.isTutorialExample else { throw CoorditFitLabError.invalidDraft("상품과 같은 종류의 옷을 촬영해주세요.") }
        _ = try CoorditGarmentMeasurement(id: measurement.id, method: measurement.method, measuredAt: measurement.measuredAt, segments: measurement.segments, lengthBasis: measurement.lengthBasis, category: measurement.category)
        isPreparingCameraAnalysis = true
        defer { isPreparingCameraAnalysis = false }
        let generation = operationGeneration
        if cameraMeasurement?.id != measurement.id || cameraReference == nil {
            let existing = cameraReference
            let receipt = try await selectedAPI.saveCameraReference(measurement: measurement, existing: existing)
            guard generation == operationGeneration, (authenticatedUserID == nil || activeHistoryUserID == owner) else { throw CoorditFitLabError.cancelled }
            cameraMeasurement = measurement
            cameraReference = receipt
            if let previousAnalysis = recommendation, existing != nil { cameraBundleAnalysisID = cameraBundleAnalysisID ?? previousAnalysis.fitAnalysisResultID }
            recommendation = nil; report = nil; reportFailureMessage = nil
            checkpoint.idempotencyKey = nil; checkpoint.reportIdempotencyKey = nil
            references.removeAll { $0.id == receipt.reference.id }
            references.append(receipt.reference)
            draft.selectedReferenceIDs = [receipt.reference.id]
            draft.isSourceConfirmed = true
            cameraSessionUserID = owner
            persistCameraSession()
        }
        if fixtureName == nil, let photo = cameraCapture.garmentPhotoData, let reference = cameraReference {
            do {
                try CoorditGarmentPhotoStore.shared.save(photo, userID: owner, clothingID: reference.reference.clothingItemID)
            } catch {
                throw CoorditFitLabError.transport("옷 사진을 기기에 보관하지 못했어요. 다시 시도해주세요.")
            }
        }
        analysisState = .running
        isAnalysisNoticeVisible = true
        await submit(using: selectedAPI, authenticatedUserID: owner)
        if let report { cameraBundleAnalysisID = cameraBundleAnalysisID ?? report.fitAnalysisResultID }
        persistCameraSession()
        finishBackgroundSubmission()
        guard report != nil else { throw error ?? .transport(reportFailureMessage ?? "리포트를 준비하지 못했어요. 같은 분석에서 다시 시도할 수 있어요.") }
    }

    private func persistCameraSession() {
        guard fixtureName == nil, let owner = cameraSessionUserID, let measurement = cameraMeasurement else { return }
        let state = CoorditCameraAnalysisState(userID: owner, draft: draft, measurement: measurement, reference: cameraReference, checkpoint: checkpoint, recommendation: recommendation, report: report, bundleAnalysisID: cameraBundleAnalysisID)
        do { UserDefaults.standard.set(try JSONEncoder().encode(state), forKey: cameraSessionKey(owner)) }
        catch { self.error = .transport("측정 진행 상황을 기기에 저장하지 못했어요.") }
    }

    private func cameraSessionKey(_ owner: String) -> String {
        "coordit.cameraAnalysis.v1." + SHA256.hash(data: Data(owner.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func restoreCameraSession(for owner: String?) {
        guard CoorditGarmentCaptureController.featureEnabled else { return }
        guard fixtureName == nil, cameraSessionUserID != owner else { return }
        persistCameraSession()
        if cameraSessionUserID != nil { discardAndRestart(clearCameraPersistence: false) }
        cameraSessionUserID = owner
        guard let owner, let data = UserDefaults.standard.data(forKey: cameraSessionKey(owner)) else { return }
        do {
            let state = try JSONDecoder().decode(CoorditCameraAnalysisState.self, from: data)
            guard state.userID == owner, state.draft.category == state.measurement.resolvedCategory, CoorditFitLabDraftValidation.submissionError(for: state.draft) == nil else { throw CoorditFitLabError.malformedResponse }
            _ = try CoorditGarmentMeasurement(id: state.measurement.id, method: state.measurement.method, measuredAt: state.measurement.measuredAt, segments: state.measurement.segments, lengthBasis: state.measurement.lengthBasis, category: state.measurement.category, arEvidence: state.measurement.arEvidence)
            draft = state.draft; cameraMeasurement = state.measurement; cameraReference = state.reference
            checkpoint = state.checkpoint; recommendation = state.recommendation; report = state.report
            createdProductID = state.checkpoint.productID
            createdSizeIDs = state.draft.sizes.compactMap { state.checkpoint.sizeIDsByDraftID[$0.id] }
            cameraBundleAnalysisID = state.bundleAnalysisID
            references = state.reference.map { [$0.reference] } ?? []
        } catch { self.error = .transport("저장한 측정을 불러오지 못했어요. 다시 측정해주세요.") }
    }

    func startSubmission(
        using overrideAPI: (any CoorditFitLabAPI)? = nil,
        authenticatedUserID: String? = nil
    ) {
        guard submissionTask == nil, !isPreparingCameraAnalysis, loadState != .loading else { return }
        analysisState = .running
        isAnalysisNoticeVisible = true
        screen = .loading
        submissionTask = Task { [weak self] in
            guard let self else { return }
            await self.submit(using: overrideAPI, authenticatedUserID: authenticatedUserID)
            self.finishBackgroundSubmission()
        }
    }

    private func finishBackgroundSubmission() {
        submissionTask = nil
        if submissionStep == .complete,
           recommendation != nil {
            analysisState = .completed(
                draft.garmentKind == .upper ? .fitLabResultTop : .fitLabResultBottom
            )
            isAnalysisNoticeVisible = report != nil
        } else if let error {
            analysisState = .failed(error.errorDescription ?? "핏 분석을 완료하지 못했어요.")
            isAnalysisNoticeVisible = true
        } else {
            analysisState = .idle
            isAnalysisNoticeVisible = false
        }
    }

    func dismissAnalysisNotice() {
        isAnalysisNoticeVisible = false
    }

    var fixtureAccessibilityIdentifier: String {
        switch screen {
        case .input: "fitlab-fixture-input-ready"
        case .loading: "fitlab-fixture-loading-submitting"
        case .resultUpper: "fitlab-fixture-result-upper"
        case .resultLower: "fitlab-fixture-result-lower"
        case .historyRegister: "fitlab-fixture-history-register"
        case .historyDetail: "fitlab-fixture-history-detail"
        case .loginRequired: "fitlab-login-required"
        }
    }

    func prefillProduct(
        from url: URL,
        category: CoorditFitLabCategory?
    ) async throws -> CoorditFitLabURLPrefillResponse {
        guard let api else {
            throw CoorditFitLabError.transport("상품 링크 API를 준비할 수 없어요.")
        }
        return try await api.prefillProduct(
            from: CoorditFitLabURLPrefillRequest(url: url, category: category)
        )
    }

    func fetchCompatibleReferences(
        category: CoorditFitLabCategory,
        using overrideAPI: (any CoorditFitLabAPI)? = nil
    ) async throws -> [CoorditFitLabReferenceRow] {
        guard let selectedAPI = overrideAPI ?? api else {
            throw CoorditFitLabError.transport("기준 옷 API를 준비할 수 없어요.")
        }
        return try await selectedAPI.compatibleReferences(category: category)
    }

    func loadCompatibleReferences(
        using overrideAPI: (any CoorditFitLabAPI)? = nil,
        authenticatedUserID: String? = nil
    ) async {
        guard loadState != .loading else { return }
        if draft.isTutorialExample {
            references = CoorditTutorialExample.references(category: draft.category)
            draft.selectedReferenceIDs.formIntersection(Set(references.map(\.id)))
            loadState = .loaded
            error = nil
            return
        }
        guard (authenticatedUserID ?? userID) != nil else {
            configureLandmarkGateway(using: nil)
            error = .loginRequired
            retryStep = .idle
            loadState = .failed(.loginRequired)
            screen = .loginRequired
            return
        }
        guard let selectedAPI = overrideAPI ?? api else {
            configureLandmarkGateway(using: nil)
            error = .transport("핏 분석 API를 준비할 수 없어요.")
            loadState = .failed(error ?? .malformedResponse)
            return
        }

        configureLandmarkGateway(using: selectedAPI as? CoorditFitLabHTTPAPI)
        operationGeneration += 1
        let generation = operationGeneration
        error = nil
        retryStep = nil
        do {
            loadState = .loading
            submissionStep = .loadingReferences
            let requestedCategory = draft.category
            let loadedReferences = try await selectedAPI.compatibleReferences(category: requestedCategory)
            guard generation == operationGeneration, !Task.isCancelled else { return }
            references = loadedReferences.filter {
                $0.category.isCompatible(with: requestedCategory) && $0.isActive
            }
            draft.selectedReferenceIDs.formIntersection(Set(references.map(\.id)))
            submissionStep = .idle
            loadState = .loaded
            error = nil
            retryStep = nil
        } catch let fitError as CoorditFitLabError {
            guard generation == operationGeneration else { return }
            error = fitError
            retryStep = submissionStep
            loadState = .failed(fitError)
        } catch {
            guard generation == operationGeneration else { return }
            let wrapped = CoorditFitLabError.transport(error.localizedDescription)
            self.error = wrapped
            retryStep = submissionStep
            loadState = .failed(wrapped)
        }
    }

    var canSubmit: Bool {
        guard draft.isSourceConfirmed, !draft.sizes.isEmpty else { return false }
        let compatibleIDs = Set(references.filter {
            $0.category.isCompatible(with: draft.category) && $0.isActive
        }.map(\.id))
        return !draft.selectedReferenceIDs.isEmpty && draft.selectedReferenceIDs.isSubset(of: compatibleIDs)
    }

    func toggleReference(_ reference: CoorditFitLabReferenceRow) {
        guard loadState != .loading,
              reference.category.isCompatible(with: draft.category),
              reference.isActive,
              references.contains(where: { $0.id == reference.id })
        else { return }
        if draft.selectedReferenceIDs.contains(reference.id) {
            draft.selectedReferenceIDs.remove(reference.id)
        } else {
            draft.selectedReferenceIDs.insert(reference.id)
        }
        error = nil
    }

    @discardableResult
    func selectReference(id: String) -> Bool {
        guard loadState != .loading,
              let reference = references.first(where: { $0.id == id }),
              reference.category.isCompatible(with: draft.category),
              reference.isActive
        else { return false }
        draft.selectedReferenceIDs.insert(reference.id)
        error = nil
        return true
    }

    func submit(
        using overrideAPI: (any CoorditFitLabAPI)? = nil,
        authenticatedUserID: String? = nil
    ) async {
        guard loadState != .loading else { return }
        if draft.isTutorialExample {
            guard canSubmit, CoorditFitLabDraftValidation.submissionError(for: draft) == nil else {
                fail(.invalidDraft("사이즈표를 확인하고 예시 기준 옷을 선택해 주세요."), at: .idle)
                return
            }
            let example = CoorditTutorialExample.recommendation(for: draft)
            recommendation = example
            report = CoorditTutorialExample.report(for: example)
            reportFailureMessage = nil
            error = nil
            submissionStep = .complete
            loadState = .loaded
            screen = draft.garmentKind == .upper ? .resultUpper : .resultLower
            return
        }
        guard (authenticatedUserID ?? userID) != nil else {
            fail(.loginRequired, at: .idle)
            screen = .loginRequired
            return
        }
        guard let selectedAPI = overrideAPI ?? api else {
            fail(.transport("핏 분석 API를 준비할 수 없어요."), at: .idle)
            return
        }
        if let validationError = CoorditFitLabDraftValidation.submissionError(for: draft) {
            fail(.invalidDraft(validationError), at: .idle)
            return
        }
        guard draft.isSourceConfirmed else {
            fail(.invalidDraft("사이즈표를 먼저 확인해 주세요."), at: .idle)
            return
        }
        let compatibleIDs = Set(references.filter {
            $0.category.isCompatible(with: draft.category) && $0.isActive
        }.map(\.id))
        guard !draft.selectedReferenceIDs.isEmpty,
              draft.selectedReferenceIDs.isSubset(of: compatibleIDs)
        else {
            fail(.invalidDraft("현재 카테고리와 맞는 기준 옷을 하나 이상 선택해 주세요."), at: .loadingReferences)
            return
        }

        operationGeneration += 1
        let generation = operationGeneration
        error = nil
        retryStep = nil
        reportFailureMessage = nil
        loadState = .loading
        screen = .loading
        do {
            if checkpoint.productID == nil {
                submissionStep = .creatingProduct
                let product = try await selectedAPI.createProduct(productRequest)
                try ensureActive(generation)
                checkpoint.productID = product.id
                createdProductID = product.id
                persistCameraSession()
            }

            guard let productID = checkpoint.productID else {
                throw CoorditFitLabError.malformedResponse
            }
            for row in draft.sizes where checkpoint.sizeIDsByDraftID[row.id] == nil {
                submissionStep = .creatingSizes
                do {
                    let created = try await selectedAPI.createSize(
                        productID: productID,
                        request: sizeRequest(for: row)
                    )
                    try ensureActive(generation)
                    checkpoint.sizeIDsByDraftID[row.id] = created.id
                    createdSizeIDs = draft.sizes.compactMap { checkpoint.sizeIDsByDraftID[$0.id] }
                    persistCameraSession()
                } catch {
                    let message = "\(row.label) 사이즈 저장에 실패했어요. 완료된 단계는 유지했어요."
                    throw CoorditFitLabError.transport(message)
                }
            }

            if recommendation == nil {
                submissionStep = .recommending
                let idempotencyKey = submissionIdempotencyKey(
                    for: authenticatedUserID ?? userID ?? "coordit-fitlab-unknown-user"
                )
                checkpoint.idempotencyKey = idempotencyKey
                let receivedRecommendation = try await selectedAPI.recommend(
                    CoorditFitLabRecommendationRequest(
                        referenceClothingIDs: draft.selectedReferenceIDs.sorted(),
                        externalProductID: productID,
                        idempotencyKey: idempotencyKey,
                        comparisonBundleAnalysisID: cameraMeasurement == nil ? nil : cameraBundleAnalysisID
                    )
                )
                try ensureActive(generation)
                recommendation = receivedRecommendation
                authoritativeThreadBalance = receivedRecommendation.availableThreads
                clearPendingSubmissionIdempotencyKey()
            }

            guard let recommendation else { throw CoorditFitLabError.malformedResponse }
            if report == nil {
                submissionStep = .generatingReport
                do {
                    let receivedReport = try await selectedAPI.report(
                        analysisID: recommendation.fitAnalysisResultID,
                        request: CoorditFitLabReportRequest(
                            idempotencyKey: reportIdempotencyKey(),
                            selectedSizeLabel: recommendation.recommendedSize,
                            style: nil,
                            comparisonBundleAnalysisID: cameraBundleAnalysisID,
                            cameraComparison: cameraMeasurement == nil ? nil : true
                        )
                    )
                    try ensureActive(generation)
                    report = receivedReport
                    authoritativeThreadBalance = receivedReport.availableThreads
                    reportFailureMessage = nil
                } catch let fitError as CoorditFitLabError {
                    try ensureActive(generation)
                    if case .server(statusCode: 402, message: _) = fitError {
                        throw fitError
                    }
                    reportFailureMessage = fitError.errorDescription
                } catch {
                    try ensureActive(generation)
                    reportFailureMessage = error.localizedDescription
                }
            }

            submissionStep = .complete
            loadState = .loaded
            screen = draft.garmentKind == .upper ? .resultUpper : .resultLower
        } catch let fitError as CoorditFitLabError {
            guard generation == operationGeneration else { return }
            fail(fitError, at: submissionStep)
        } catch {
            guard generation == operationGeneration else { return }
            fail(.transport(error.localizedDescription), at: submissionStep)
        }
    }

    func discardAndRestart(clearCameraPersistence: Bool = true) {
        isComparisonRequested = false
        if clearCameraPersistence, fixtureName == nil, let owner = cameraSessionUserID { UserDefaults.standard.removeObject(forKey: cameraSessionKey(owner)) }
        cameraMeasurement = nil; cameraReference = nil; cameraBundleAnalysisID = nil
        cameraCapture.clearCapture()
        submissionTask?.cancel()
        submissionTask = nil
        operationGeneration += 1
        clearPendingSubmissionIdempotencyKey()
        checkpoint = CoorditFitLabSubmissionCheckpoint()
        createdProductID = nil
        createdSizeIDs = []
        recommendation = nil
        report = nil
        reportFailureMessage = nil
        references = []
        draft = CoorditFitLabDraft()
        submissionStep = .idle
        loadState = .idle
        error = nil
        retryStep = nil
        screen = .input
        analysisState = .idle
        isAnalysisNoticeVisible = false
    }

    func cancelSubmission() {
        submissionTask?.cancel()
        submissionTask = nil
        operationGeneration += 1
        submissionStep = .idle
        loadState = .idle
        error = nil
        retryStep = nil
        reportFailureMessage = nil
        analysisState = .idle
        isAnalysisNoticeVisible = false
    }

    private var productRequest: CoorditFitLabProductRequest {
        CoorditFitLabProductRequest(
            productName: draft.productName,
            brand: draft.brand,
            mallName: draft.mallName,
            productURL: draft.productURL,
            category: draft.category,
            fitType: "regular"
        )
    }

    private func sizeRequest(for row: CoorditFitLabSizeDraft) -> CoorditFitLabSizeRequest {
        CoorditFitLabSizeRequest(
            sizeLabel: row.label,
            measurements: row.measurements,
            parsingStatus: draft.source == .url ? "confirmed" : nil,
            measurementSource: draft.source.rawValue,
            extractedText: draft.ocrMetadata?.extractedText,
            extractionConfidence: draft.ocrMetadata?.confidence
        )
    }

    private func ensureActive(_ generation: Int) throws {
        guard generation == operationGeneration, !Task.isCancelled else {
            throw CoorditFitLabError.cancelled
        }
    }

    private func submissionIdempotencyKey(for authenticatedUserID: String) -> String {
        if let idempotencyKey = checkpoint.idempotencyKey { return idempotencyKey }

        let fingerprint = submissionFingerprint(for: authenticatedUserID)
        if let pending = Self.pendingSubmissionKey(), pending.fingerprint == fingerprint {
            checkpoint.idempotencyKey = pending.idempotencyKey
            return pending.idempotencyKey
        }

        let idempotencyKey = UUID().uuidString
        checkpoint.idempotencyKey = idempotencyKey
        persistCameraSession()
        Self.savePendingSubmissionKey(.init(fingerprint: fingerprint, idempotencyKey: idempotencyKey))
        return idempotencyKey
    }

    private func reportIdempotencyKey() -> String {
        if let idempotencyKey = checkpoint.reportIdempotencyKey { return idempotencyKey }
        let idempotencyKey = UUID().uuidString
        checkpoint.reportIdempotencyKey = idempotencyKey
        persistCameraSession()
        return idempotencyKey
    }

    private func submissionFingerprint(for authenticatedUserID: String) -> String {
        let payload = SubmissionFingerprint(
            userID: authenticatedUserID,
            source: draft.source,
            category: draft.category,
            productName: draft.productName,
            productURL: draft.productURL,
            sizes: draft.sizes,
            referenceIDs: draft.selectedReferenceIDs.sorted()
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = (try? encoder.encode(payload)) ?? Data()
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func clearPendingSubmissionIdempotencyKey() {
        UserDefaults.standard.removeObject(forKey: Self.pendingIdempotencyKeyDefaultsKey)
    }

    private static func pendingSubmissionKey() -> PendingSubmissionKey? {
        guard let data = UserDefaults.standard.data(forKey: pendingIdempotencyKeyDefaultsKey) else { return nil }
        return try? JSONDecoder().decode(PendingSubmissionKey.self, from: data)
    }

    private static func savePendingSubmissionKey(_ pending: PendingSubmissionKey) {
        guard let data = try? JSONEncoder().encode(pending) else { return }
        UserDefaults.standard.set(data, forKey: pendingIdempotencyKeyDefaultsKey)
    }

    private func fail(_ failure: CoorditFitLabError, at step: CoorditFitLabSubmissionStep) {
        error = failure
        retryStep = step
        loadState = .failed(failure)
    }

    func synchronize(route: CoorditFrameRoute) {
        if route == .fitLabLoading {
            screen = .loading
            return
        }
        operationGeneration += 1
        screen = Self.screen(for: route)
        error = nil
        retryStep = nil
        submissionStep = .idle
        loadState = .idle
        #if DEBUG
        if fixtureName != nil {
            seed(route: route, fixture: fixtureName)
        }
        #endif
    }

    func loadHistory() async {
        await switchHistoryUser(to: activeHistoryUserID ?? userID)
    }

    func prepareHistory(userID: String?) async {
        if activeHistoryUserID != userID { cameraCapture.clearCapture() }
        restoreCameraSession(for: userID)
        await switchHistoryUser(to: userID)
    }

    @discardableResult
    func deleteLocalHistory(for userID: String) async -> Bool {
        UserDefaults.standard.removeObject(forKey: cameraSessionKey(userID))
        if cameraSessionUserID == userID { discardAndRestart(clearCameraPersistence: false); cameraSessionUserID = nil }
        historyGeneration += 1
        historyMutationGeneration += 1
        historyMutationTask?.cancel()
        historyMutationTask = nil
        savedHistory = []
        selectedHistory = nil
        historyRecoveryNotice = nil
        if activeHistoryUserID == userID {
            activeHistoryUserID = nil
        }
        guard let historyStore else { return true }
        do {
            try await historyStore.deleteAll(userID: userID)
            return true
        } catch {
            self.error = .transport(error.localizedDescription)
            return false
        }
    }

    func switchHistoryUser(to userID: String?) async {
        historyGeneration += 1
        historyMutationGeneration += 1
        historyMutationTask?.cancel()
        historyMutationTask = nil
        let generation = historyGeneration
        activeHistoryUserID = userID
        savedHistory = []
        selectedHistory = nil
        historyRecoveryNotice = nil
        guard let userID else { return }
        await reloadHistory(userID: userID, generation: generation)
    }

    private func reloadHistory(userID: String, generation: Int) async {
        guard let historyStore else { return }
        do {
            let transferNotice: String?
            do {
                try await historyStore.completePendingGuestTransfers(to: userID)
                transferNotice = nil
            } catch {
                transferNotice = "비회원 기록을 아직 모두 옮기지 못했어요. 원본은 보관 중이며 다시 열면 재시도해요."
            }
            let snapshots = try await historyStore.load(userID: userID)
            let recoveryNotice = await historyStore.recoveryNotice(userID: userID)
            guard generation == historyGeneration, activeHistoryUserID == userID else { return }
            savedHistory = snapshots
            historyRecoveryNotice = transferNotice ?? recoveryNotice
            if selectedHistory == nil,
               screen == .historyDetail || screen == .historyRegister {
                selectedHistory = snapshots.first
            }
        } catch {
            guard generation == historyGeneration, activeHistoryUserID == userID else { return }
            self.error = .transport(error.localizedDescription)
        }
    }

    @discardableResult
    func saveCurrentAnalysis(authenticatedUserID: String? = nil) async -> Bool {
        guard !draft.isTutorialExample else { return false }
        guard
            let historyStore,
            let userID = authorizedHistoryUser(authenticatedUserID),
            let snapshot = makeHistorySnapshot(userID: userID, savedAt: Date())
        else { return false }
        let generation = historyGeneration
        historyMutationTask?.cancel()
        historyMutationGeneration += 1
        let mutationGeneration = historyMutationGeneration
        let task = Task { () -> Bool in
            do {
                try Task.checkCancellation()
                try await historyStore.save(snapshot)
                try Task.checkCancellation()
                return true
            } catch { return false }
        }
        historyMutationTask = task
        let stored = await task.value
        guard mutationGeneration == historyMutationGeneration else { return false }
        historyMutationTask = nil
        do {
            guard stored else { throw CancellationError() }
            guard generation == historyGeneration, activeHistoryUserID == userID else { return true }
            await reloadHistory(userID: userID, generation: generation)
            guard generation == historyGeneration, activeHistoryUserID == userID else { return true }
            selectedHistory = savedHistory.first { $0.analysisID == snapshot.analysisID }
            return true
        } catch {
            guard generation == historyGeneration, activeHistoryUserID == userID else { return false }
            self.error = .transport(error.localizedDescription)
            return false
        }
    }

    func selectHistory(_ snapshot: CoorditFitLabHistorySnapshot) {
        guard snapshot.userID == activeHistoryUserID else { return }
        selectedHistory = snapshot
    }

    @discardableResult
    func deleteSelectedHistory(authenticatedUserID: String? = nil) async -> Bool {
        guard let historyStore, let selectedHistory,
              let userID = authorizedHistoryUser(authenticatedUserID),
              selectedHistory.userID == userID else { return false }
        let generation = historyGeneration
        historyMutationTask?.cancel()
        historyMutationGeneration += 1
        let mutationGeneration = historyMutationGeneration
        let task = Task { () -> Bool in
            do {
                try Task.checkCancellation()
                try await historyStore.delete(snapshotID: selectedHistory.id, userID: userID)
                try Task.checkCancellation()
                return true
            } catch { return false }
        }
        historyMutationTask = task
        let deleted = await task.value
        guard mutationGeneration == historyMutationGeneration else { return false }
        historyMutationTask = nil
        do {
            guard deleted else { throw CancellationError() }
            guard generation == historyGeneration, activeHistoryUserID == userID else { return true }
            self.selectedHistory = nil
            await reloadHistory(userID: userID, generation: generation)
            return true
        } catch {
            guard generation == historyGeneration, activeHistoryUserID == userID else { return false }
            self.error = .transport(error.localizedDescription)
            return false
        }
    }

    private func authorizedHistoryUser(_ authenticatedUserID: String?) -> String? {
        #if DEBUG
        if fixtureName != nil {
            let candidate = authenticatedUserID ?? activeHistoryUserID ?? userID
            return candidate == activeHistoryUserID ? candidate : nil
        }
        #endif
        guard let authenticatedUserID, authenticatedUserID == activeHistoryUserID else { return nil }
        return authenticatedUserID
    }

    private func makeHistorySnapshot(
        userID: String,
        savedAt: Date,
        analysisID: String? = nil,
        recommendation overrideRecommendation: CoorditFitLabRecommendationResponse? = nil
    ) -> CoorditFitLabHistorySnapshot? {
        guard let recommendation = overrideRecommendation ?? recommendation else { return nil }
        let resolvedAnalysisID = analysisID ?? recommendation.fitAnalysisResultID
        let referenceSummaries = draft.selectedReferenceIDs.sorted().map { id in
            let reference = references.first { $0.id == id }
            return CoorditFitLabHistorySnapshot.ReferenceSummary(
                id: id,
                name: reference?.nickname ?? reference?.clothingItemID ?? id
            )
        }
        return CoorditFitLabHistorySnapshot(
            id: resolvedAnalysisID,
            analysisID: resolvedAnalysisID,
            userID: userID,
            savedAt: savedAt,
            product: .init(
                name: draft.productName,
                brand: draft.brand,
                mallName: draft.mallName,
                url: draft.productURL
            ),
            category: draft.category,
            garmentKind: draft.garmentKind,
            references: referenceSummaries,
            originalSource: draft.source,
            recommendation: recommendation,
            report: report,
            chartData: report?.chartData ?? .init()
        )
    }

    #if DEBUG
    func seedRetentionHistory() async {
        guard let historyStore, let userID = activeHistoryUserID else { return }
        let base = CoorditFitLabFixtures.upperRecommendation
        for index in 1...51 {
            let recommendation = CoorditFitLabRecommendationResponse(
                fitAnalysisResultID: "analysis-\(index)",
                recommendedSize: base.recommendedSize,
                fitScore: base.fitScore,
                fitLabel: base.fitLabel,
                fitComment: base.fitComment,
                recommendationConfidence: base.recommendationConfidence,
                diff: base.diff,
                allSizeScores: base.allSizeScores
            )
            if let snapshot = makeHistorySnapshot(
                userID: userID,
                savedAt: Date(timeIntervalSince1970: TimeInterval(index)),
                analysisID: "analysis-\(index)",
                recommendation: recommendation
            ) {
                try? await historyStore.save(snapshot)
            }
        }
        await switchHistoryUser(to: userID)
        updateHistoryEdgeProbe()
    }

    func saveDuplicateHistory() async {
        guard let historyStore, let userID = activeHistoryUserID else { return }
        let base = CoorditFitLabFixtures.upperRecommendation
        let recommendation = CoorditFitLabRecommendationResponse(
            fitAnalysisResultID: "analysis-51",
            recommendedSize: base.recommendedSize,
            fitScore: base.fitScore,
            fitLabel: base.fitLabel,
            fitComment: base.fitComment,
            recommendationConfidence: base.recommendationConfidence,
            diff: base.diff,
            allSizeScores: base.allSizeScores
        )
        if let snapshot = makeHistorySnapshot(
            userID: userID,
            savedAt: Date(timeIntervalSince1970: 10_000),
            analysisID: "analysis-51",
            recommendation: recommendation
        ) {
            try? await historyStore.save(snapshot)
        }
        await switchHistoryUser(to: userID)
        updateHistoryEdgeProbe()
    }

    func debugSwitchHistoryUser(to userID: String) async {
        await switchHistoryUser(to: userID)
        historyUserProbe = "user=\(userID)|count=\(savedHistory.count)"
    }

    func corruptHistory() async {
        guard
            let userID = activeHistoryUserID,
            let store = historyStore as? CoorditFitLabFileHistoryStore
        else { return }
        do {
            try await store.debugCorrupt(userID: userID)
            await switchHistoryUser(to: userID)
            historyQuarantineCount = try await store.debugQuarantineCount(userID: userID)
        } catch {
            self.error = .transport(error.localizedDescription)
        }
    }

    func runHistoryStoreAudit() async {
        guard
            let userID = activeHistoryUserID,
            let store = historyStore as? CoorditFitLabFileHistoryStore,
            let sample = makeHistorySnapshot(
                userID: userID,
                savedAt: Date(),
                recommendation: CoorditFitLabFixtures.upperRecommendation
            )
        else { return }
        historyStoreAudit = await store.debugAudit(sample: sample)
    }

    func runHistoryRaceAudit() async {
        let userA = "history-user-a"
        let userB = "history-user-b"
        let userASnapshot = Self.raceSnapshot(userID: userA, analysisID: "race-a")
        let userBSnapshot = Self.raceSnapshot(userID: userB, analysisID: "race-b")

        let loadStore = CoorditFitLabSuspendingHistoryStore(
            snapshots: [userASnapshot, userBSnapshot],
            suspendedLoadUserID: userA
        )
        let loadCoordinator = CoorditFitLabCoordinator(
            route: .fitLabInput,
            configuration: .init(name: "history-edge", userID: userA, historyRootDirectory: nil, resetsHistory: false),
            historyStore: loadStore
        )
        let loadTask = Task { await loadCoordinator.prepareHistory(userID: userA) }
        await loadStore.waitForLoadStart()
        await loadCoordinator.prepareHistory(userID: userB)
        await loadStore.releaseLoad()
        await loadTask.value
        let loadPassed = loadCoordinator.activeHistoryUserID == userB
            && loadCoordinator.savedHistory == [userBSnapshot]

        let saveStore = CoorditFitLabSuspendingHistoryStore(snapshots: [userBSnapshot])
        let saveCoordinator = CoorditFitLabCoordinator(
            route: .fitLabResultTop,
            configuration: .init(name: "upper-result", userID: userA, historyRootDirectory: nil, resetsHistory: false),
            historyStore: saveStore
        )
        await saveCoordinator.prepareHistory(userID: userA)
        let saveTask = Task { await saveCoordinator.saveCurrentAnalysis(authenticatedUserID: userA) }
        await saveStore.waitForSaveStart()
        await saveCoordinator.prepareHistory(userID: userB)
        await saveStore.releaseSave()
        _ = await saveTask.value
        let savePassed = saveCoordinator.activeHistoryUserID == userB
            && saveCoordinator.savedHistory == [userBSnapshot]

        let deleteStore = CoorditFitLabSuspendingHistoryStore(snapshots: [userASnapshot, userBSnapshot])
        let deleteCoordinator = CoorditFitLabCoordinator(
            route: .fitLabInput,
            configuration: .init(name: "history-edge", userID: userA, historyRootDirectory: nil, resetsHistory: false),
            historyStore: deleteStore
        )
        await deleteCoordinator.prepareHistory(userID: userA)
        deleteCoordinator.selectHistory(userASnapshot)
        let deleteTask = Task { await deleteCoordinator.deleteSelectedHistory() }
        await deleteStore.waitForDeleteStart()
        await deleteCoordinator.prepareHistory(userID: userB)
        await deleteStore.releaseDelete()
        _ = await deleteTask.value
        let deletePassed = deleteCoordinator.activeHistoryUserID == userB
            && deleteCoordinator.savedHistory == [userBSnapshot]
            && deleteCoordinator.selectedHistory == nil

        historyRaceProbe = "load=\(loadPassed ? "pass" : "fail")|save=\(savePassed ? "pass" : "fail")|delete=\(deletePassed ? "pass" : "fail")"
    }

    func runHistoryF2Audit() async {
        let userA = "history-user-a"
        let userB = "history-user-b"

        let saveStore = CoorditFitLabSuspendingHistoryStore(snapshots: [])
        let saveCoordinator = CoorditFitLabCoordinator(
            route: .fitLabResultTop,
            configuration: .init(name: "upper-result", userID: userA, historyRootDirectory: nil, resetsHistory: false),
            historyStore: saveStore
        )
        await saveCoordinator.prepareHistory(userID: userA)
        let saveTask = Task { await saveCoordinator.saveCurrentAnalysis(authenticatedUserID: userA) }
        await saveStore.waitForSaveStart()
        await saveCoordinator.prepareHistory(userID: nil)
        await saveStore.releaseSave()
        _ = await saveTask.value
        let savePassed = !(await saveStore.contains(analysisID: "analysis-fixture-upper", userID: userA))
            && saveCoordinator.activeHistoryUserID == nil
            && saveCoordinator.savedHistory.isEmpty

        let userASnapshot = Self.raceSnapshot(userID: userA, analysisID: "race-a")
        let deleteStore = CoorditFitLabSuspendingHistoryStore(snapshots: [userASnapshot])
        let deleteCoordinator = CoorditFitLabCoordinator(
            route: .fitLabInput,
            configuration: .init(name: "history-edge", userID: userA, historyRootDirectory: nil, resetsHistory: false),
            historyStore: deleteStore
        )
        await deleteCoordinator.prepareHistory(userID: userA)
        deleteCoordinator.selectHistory(userASnapshot)
        let deleteTask = Task { await deleteCoordinator.deleteSelectedHistory(authenticatedUserID: userA) }
        await deleteStore.waitForDeleteStart()
        await deleteCoordinator.prepareHistory(userID: userB)
        await deleteStore.releaseDelete()
        _ = await deleteTask.value
        let deletePassed = await deleteStore.contains(analysisID: "race-a", userID: userA)
            && deleteCoordinator.activeHistoryUserID == userB
            && deleteCoordinator.savedHistory.isEmpty

        let migrationAudit: String
        if let fileStore = historyStore as? CoorditFitLabFileHistoryStore {
            migrationAudit = await fileStore.debugMigrationRewriteFailureAudit()
        } else {
            migrationAudit = "unavailable"
        }
        let migrationPassed = migrationAudit == "loaded=1|analysis=legacy-analysis|retained=true|quarantine=0|notice=present"
        historyF2Probe = "save=\(savePassed ? "pass" : "fail")|delete=\(deletePassed ? "pass" : "fail")|migration-write=\(migrationPassed ? "pass" : "fail")|legacy-retained=\(migrationPassed ? "pass" : "fail")"
        if !migrationPassed { historyF2Probe += "|detail=\(migrationAudit)" }
    }

    private static func raceSnapshot(userID: String, analysisID: String) -> CoorditFitLabHistorySnapshot {
        CoorditFitLabHistorySnapshot(
            id: analysisID,
            analysisID: analysisID,
            userID: userID,
            savedAt: Date(timeIntervalSince1970: 1),
            product: .init(name: analysisID, brand: nil, mallName: nil, url: nil),
            category: .hoodie,
            garmentKind: .upper,
            references: [],
            originalSource: .manual,
            recommendation: CoorditFitLabFixtures.upperRecommendation,
            report: nil,
            chartData: .init()
        )
    }

    private func updateHistoryEdgeProbe() {
        let unique = Set(savedHistory.map(\.analysisID)).count
        historyEdgeProbe = "count=\(savedHistory.count)|unique=\(unique)|newest=\(savedHistory.first?.analysisID ?? "none")|oldest=\(savedHistory.last?.analysisID ?? "none")"
        if let userID = activeHistoryUserID {
            historyUserProbe = "user=\(userID)|count=\(savedHistory.count)"
        }
    }
    #endif

    #if DEBUG
    private func seed(route: CoorditFrameRoute, fixture: String?) {
        guard fixture != nil else { return }
        if fixture?.hasPrefix("camera-") == true {
            if fixture == "camera-demo" { return }
            if route == .fitLabInput, cameraMeasurement == nil {
                draft = CoorditFitLabDraft(source: .url, garmentKind: .upper, category: .tshirt, productName: "코튼 크루넥 티셔츠", sizes: [
                .init(label: "M", measurements: [.shoulderWidth: 48, .chestWidth: 54, .totalLength: 68, .sleeveLength: 22]),
                .init(label: "L", measurements: [.shoulderWidth: 50, .chestWidth: 57, .totalLength: 71, .sleeveLength: 23])
                ], isSourceConfirmed: true)
            }
            return
        }
        switch route {
        case .fitLabLoading:
            submissionStep = .creatingSizes
            loadState = .loading
        case .fitLabResultTop:
            draft = CoorditFitLabFixtures.upperResultDraft
            recommendation = CoorditFitLabFixtures.upperRecommendation
            report = fixture == "long-report" ? CoorditFitLabFixtures.longReport : CoorditFitLabFixtures.report
        case .fitLabResultBottom:
            if fixture == "size-score-numeric-labels" {
                draft = CoorditFitLabFixtures.lowerNumericSizeLabelResultDraft
                recommendation = CoorditFitLabFixtures.lowerNumericSizeLabelRecommendation
                report = CoorditFitLabFixtures.lowerNumericSizeLabelReport
            } else {
                draft = CoorditFitLabFixtures.lowerResultDraft
                recommendation = CoorditFitLabFixtures.lowerRecommendation
                report = CoorditFitLabFixtures.lowerReport
            }
        case .fitLabHistoryRegister, .fitLabHistoryDetail:
            recommendation = CoorditFitLabFixtures.lowerRecommendation
            report = CoorditFitLabFixtures.lowerReport
            if fixture == "saved-history" {
                selectedHistory = makeHistorySnapshot(
                    userID: userID ?? "coordit-fitlab-test-user",
                    savedAt: Date(timeIntervalSince1970: 1_700_000_000)
                )
            }
        default:
            break
        }
    }
    #endif

    private static func screen(for route: CoorditFrameRoute) -> CoorditFitLabScreen {
        switch route {
        case .fitLabLoading: .loading
        case .fitLabResultTop: .resultUpper
        case .fitLabResultBottom: .resultLower
        case .fitLabHistoryRegister: .historyRegister
        case .fitLabHistoryDetail: .historyDetail
        default: .input
        }
    }
}
#endif
