import Foundation
import Combine

#if os(iOS)
@MainActor
final class CoorditBackendSessionStore: ObservableObject {
    @Published private(set) var session: CoorditAuthSession?
    @Published private(set) var profile: CoorditUserProfile?
    @Published private(set) var latestBodyMeasurement: CoorditBodyMeasurement?
    @Published private(set) var statusText = "백엔드 연결 확인 전"
    @Published private(set) var isWorking = false
    @Published private(set) var isWarning = false

    private let client: CoorditBackendClient
    private let tokenStore: CoorditBackendTokenStore

    init() {
        self.client = CoorditBackendClient(baseURL: CoorditBackendConfig.baseURL())
        self.tokenStore = CoorditBackendTokenStore()
        session = tokenStore.load()
    }

    init(client: CoorditBackendClient, tokenStore: CoorditBackendTokenStore) {
        self.client = client
        self.tokenStore = tokenStore
        session = tokenStore.load()
    }

    var isAuthenticated: Bool {
        session != nil
    }

    var emailText: String {
        profile?.email ?? session?.user.email ?? "로그인 필요"
    }

    var displayNameText: String {
        profile?.displayName ?? session?.user.email ?? "코딧 사용자"
    }

    func bootstrap() async {
        await run {
            let health = try await client.health()
            statusText = health.ok ? "\(health.service) 연결됨" : "백엔드 응답이 불안정해요."
            isWarning = !health.ok
            if session != nil {
                try await refreshAccount()
            }
        }
    }

    func login(email: String, password: String) async {
        await authenticate {
            try await client.login(email: email, password: password)
        }
    }

    func signup(email: String, password: String) async {
        await authenticate {
            try await client.signup(email: email, password: password)
        }
    }

    func logout() {
        tokenStore.delete()
        session = nil
        profile = nil
        latestBodyMeasurement = nil
        statusText = "이 기기에서 로그아웃했어요."
        isWarning = false
    }

    func saveProfile(displayName: String) async {
        await runAuthenticated { token in
            profile = try await client.updateMe(token: token, displayName: displayName)
            statusText = "프로필을 백엔드에 저장했어요."
            isWarning = false
        }
    }

    func saveBodyMeasurement(_ request: BodyMeasurementRequest) async {
        await runAuthenticated { token in
            latestBodyMeasurement = try await client.createBodyMeasurement(token: token, request: request)
            statusText = "신체 치수를 백엔드에 저장했어요."
            isWarning = false
        }
    }

    func saveReferenceClothing(from draft: CoorditClosetDraft) async -> CoorditReferenceSaveResult? {
        guard let token = session?.accessToken else {
            statusText = "기준 옷 저장은 로그인 후 백엔드에 반영돼요."
            isWarning = true
            return nil
        }

        isWorking = true
        defer { isWorking = false }

        do {
            let clothingItem = try await client.createClothingItem(token: token, request: draft.clothingItemRequest)
            let clothingSizeRequest = await CoorditFitLabSizeExtractor.referenceClothingSizeRequest(from: draft)
            _ = try await client.createClothingSize(
                token: token,
                clothingItemId: clothingItem.id,
                request: clothingSizeRequest
            )
            let reference = try await client.createReferenceClothing(
                token: token,
                request: draft.referenceRequest(clothingItemId: clothingItem.id)
            )
            statusText = "기준 옷을 핏 엔진에 저장했어요."
            isWarning = false
            return CoorditReferenceSaveResult(
                clothingItemId: clothingItem.id,
                referenceClothingId: reference.id
            )
        } catch {
            statusText = error.localizedDescription
            isWarning = true
            return nil
        }
    }

    func recommendFitLabTarget(category: CoorditClosetCategory, sizeChartImageData: Data?) async -> CoorditFitRecommendation? {
        guard let token = session?.accessToken else {
            statusText = "핏 엔진 계산은 로그인이 필요해요."
            isWarning = true
            return nil
        }

        isWorking = true
        defer { isWorking = false }

        do {
            let references = try await client.listReferenceClothing(token: token, category: category.backendCategory)
            guard let reference = references.first else {
                statusText = "먼저 \(category.title) 기준 옷을 하나 등록해주세요."
                isWarning = true
                return nil
            }

            let externalProduct = try await client.createExternalProduct(
                token: token,
                request: CreateExternalProductRequest(
                    productName: "Fit Lab 등록 상품",
                    brand: nil,
                    mallName: nil,
                    productUrl: nil,
                    category: category.backendCategory,
                    fitType: "regular",
                    rawProductData: ["source": "ios-fitlab"]
                )
            )

            let candidateSizes = await CoorditFitLabSizeExtractor.candidateSizes(
                from: sizeChartImageData,
                category: category
            )

            for sizeRequest in candidateSizes {
                _ = try await client.createExternalProductSize(
                    token: token,
                    externalProductId: externalProduct.id,
                    request: sizeRequest
                )
            }

            let recommendation = try await client.recommendFit(
                token: token,
                request: FitRecommendRequest(
                    referenceClothingIds: [reference.id],
                    externalProductId: externalProduct.id
                )
            )
            let usedFallbackMeasurements = candidateSizes.contains { $0.measurementSource != "ocr" }
            statusText = usedFallbackMeasurements
                ? "사이즈표를 읽지 못해 기본 후보로 \(recommendation.recommendedSize) 사이즈를 추천했어요."
                : "사이즈표를 읽고 \(recommendation.recommendedSize) 사이즈를 추천했어요."
            isWarning = usedFallbackMeasurements
            return recommendation
        } catch {
            statusText = error.localizedDescription
            isWarning = true
            return nil
        }
    }

    private func authenticate(_ action: () async throws -> CoorditAuthSession) async {
        await run {
            let nextSession = try await action()
            try tokenStore.save(nextSession)
            session = nextSession
            try await refreshAccount()
            statusText = "백엔드 로그인 완료"
            isWarning = false
        }
    }

    private func refreshAccount() async throws {
        guard let token = session?.accessToken else { return }
        profile = try await client.me(token: token)
        latestBodyMeasurement = try await client.listBodyMeasurements(token: token).first
    }

    private func runAuthenticated(_ action: (String) async throws -> Void) async {
        guard let token = session?.accessToken else {
            statusText = "백엔드 저장은 로그인이 필요해요."
            isWarning = true
            return
        }
        await run {
            try await action(token)
        }
    }

    private func run(_ action: () async throws -> Void) async {
        isWorking = true
        defer { isWorking = false }

        do {
            try await action()
        } catch {
            statusText = error.localizedDescription
            isWarning = true
        }
    }
}
#endif
