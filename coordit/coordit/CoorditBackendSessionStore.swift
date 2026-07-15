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

#if DEBUG
    private let usesAuthenticatedUITestFixture: Bool
#endif

    init() {
        self.client = CoorditBackendClient(baseURL: CoorditBackendConfig.baseURL())
        self.tokenStore = CoorditBackendTokenStore()
#if DEBUG
        if Self.shouldUseAuthenticatedUITestFixture {
            usesAuthenticatedUITestFixture = true
            session = CoorditAuthSession(
                accessToken: "",
                refreshToken: "",
                user: CoorditAuthUser(id: "coordit-ui-test-user", email: "ui-test@coordit.invalid")
            )
            profile = CoorditUserProfile(
                id: "coordit-ui-test-user",
                email: "ui-test@coordit.invalid",
                displayName: "코딧 테스트 사용자",
                gender: nil,
                birthYear: nil,
                createdAt: "2026-01-01T00:00:00Z",
                updatedAt: "2026-01-01T00:00:00Z"
            )
        } else {
            usesAuthenticatedUITestFixture = false
            session = tokenStore.load()
        }
#else
        session = tokenStore.load()
#endif
    }

    init(client: CoorditBackendClient, tokenStore: CoorditBackendTokenStore) {
        self.client = client
        self.tokenStore = tokenStore
#if DEBUG
        usesAuthenticatedUITestFixture = false
#endif
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
#if DEBUG
        if usesAuthenticatedUITestFixture {
            return
        }
#endif
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

#if DEBUG
    private static var shouldUseAuthenticatedUITestFixture: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("--coordit-ui-testing")
            && arguments.contains("--coordit-ui-testing-authenticated")
    }
#endif
}
#endif
