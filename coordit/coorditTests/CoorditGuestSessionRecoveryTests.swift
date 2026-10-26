#if canImport(XCTest)
import Foundation
import Security
import XCTest
@testable import coordit

@MainActor
final class CoorditGuestSessionRecoveryTests: XCTestCase {
    func testGuestCannotEnablePurchasesOrSubmitReceipt() async throws {
        let (store, _) = try makeStore(activeGuest: true)
        _ = await store.refreshMonetizationReadiness()
        XCTAssertFalse(store.canUseInAppPurchases)
        do {
            _ = try await store.settleAppleIapPurchase(signedTransaction: "guest-receipt")
            XCTFail("Anonymous receipt must be rejected before a backend request")
        } catch let error as CoorditBackendClientError {
            if case .server(let statusCode, _) = error { XCTAssertEqual(statusCode, 403) }
            else { XCTFail("Expected account-link error") }
        }
        XCTAssertFalse(RecoveryURLProtocol.state.paths.contains("/thread-wallet/iap/verify"))
    }

    func testGuestHistoryTransferRetainsBothAccountsAndSurvivesRestart() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let history = CoorditFitLabFileHistoryStore(rootDirectory: root)
        func snapshot(user: String, analysis: String) -> CoorditFitLabHistorySnapshot {
            CoorditFitLabHistorySnapshot(
                id: analysis, analysisID: analysis, userID: user, savedAt: Date(),
                product: .init(name: "기존 옷", brand: nil, mallName: nil, url: nil),
                category: .tshirt, garmentKind: .upper, references: [], originalSource: .manual,
                recommendation: CoorditFitLabFixtures.upperRecommendation, report: nil, chartData: .init()
            )
        }
        try await history.save(snapshot(user: "guest", analysis: "guest-analysis"))
        try await history.save(snapshot(user: "member", analysis: "member-analysis"))
        for index in 0..<50 {
            try await history.save(snapshot(user: "member", analysis: "member-existing-\(index)"))
        }
        try await history.scheduleGuestTransfer(from: "guest", to: "member")
        let restarted = CoorditFitLabFileHistoryStore(rootDirectory: root)
        try await restarted.completePendingGuestTransfers(to: "member")
        let records = try await restarted.load(userID: "member")
        XCTAssertEqual(records.count, 52)
        XCTAssertTrue(records.contains { $0.analysisID == "guest-analysis" })
        XCTAssertTrue(records.contains { $0.analysisID == "member-analysis" })
        XCTAssertTrue(records.allSatisfy { $0.userID == "member" })
        try await restarted.completePendingGuestTransfers(to: "member")
        let replayed = try await restarted.load(userID: "member")
        XCTAssertEqual(replayed.count, 52)
    }

    func testCorruptGuestHistorySurvivesRepeatedTransferAttempts() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let history = CoorditFitLabFileHistoryStore(rootDirectory: root)
        _ = try await history.load(userID: "guest")
        let source = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).first)
        try Data("damaged-history".utf8).write(to: source.appendingPathComponent("history.json"))
        try await history.scheduleGuestTransfer(from: "guest", to: "member")
        for _ in 0..<2 {
            let restarted = CoorditFitLabFileHistoryStore(rootDirectory: root)
            do {
                try await restarted.completePendingGuestTransfers(to: "member")
                XCTFail("Damaged source must remain recoverable")
            } catch let error as CoorditFitLabHistoryStoreError {
                XCTAssertEqual(error, .writeFailed)
            }
        }
        let quarantined = try FileManager.default.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
        let preserved = try XCTUnwrap(quarantined.first { $0.lastPathComponent.hasPrefix("history.json.corrupt-") })
        XCTAssertEqual(try Data(contentsOf: preserved), Data("damaged-history".utf8))
    }

    func testLogoutAndGuestLoginRestoreOriginalAccountAndRemainingBalance() async throws {
        let (store, tokens) = try makeStore(activeGuest: true)
        let original = try XCTUnwrap(store.session)
        store.logout()
        XCTAssertNil(tokens.load())
        XCTAssertEqual(try tokens.loadGuestRecovery(), original)

        let balance = await store.bootstrapGuestIfNeeded()
        XCTAssertEqual(balance, 2)
        XCTAssertEqual(store.session?.user.id, original.user.id)
        XCTAssertEqual(tokens.load()?.refreshToken, "rotated-refresh")
        XCTAssertEqual(try tokens.loadGuestRecovery()?.refreshToken, "rotated-refresh")
        XCTAssertFalse(RecoveryURLProtocol.state.paths.contains("/auth/guest"))
    }

    func testFreshAppStoreRestoresKeychainGuestWithoutActiveCredentials() async throws {
        let (oldStore, tokens) = try makeStore(activeGuest: true)
        oldStore.logout()
        let installedStore = CoorditBackendSessionStore(client: client(), tokenStore: tokens)
        XCTAssertNil(installedStore.session)

        let balance = await installedStore.bootstrapGuestIfNeeded()
        XCTAssertEqual(balance, 2)
        XCTAssertEqual(installedStore.session?.user.id, "original-guest")
        XCTAssertFalse(RecoveryURLProtocol.state.paths.contains("/auth/guest"))
        installedStore.logout()
    }

    func testRecoveryServerFailureDoesNotCreateAnotherGuestAndCanRetry() async throws {
        let (store, tokens) = try makeStore(activeGuest: true)
        store.logout()
        RecoveryURLProtocol.state.refreshStatus = 503
        let failedBalance = await store.bootstrapGuestIfNeeded()
        XCTAssertNil(failedBalance)
        XCTAssertNil(store.session)
        XCTAssertEqual(try tokens.loadGuestRecovery()?.refreshToken, "original-refresh")
        XCTAssertEqual(RecoveryURLProtocol.state.paths, ["/auth/refresh"])

        RecoveryURLProtocol.state.refreshStatus = 200
        let recoveredBalance = await store.bootstrapGuestIfNeeded()
        XCTAssertEqual(recoveredBalance, 2)
        XCTAssertEqual(store.session?.user.id, "original-guest")
        store.logout()
    }

    func testRevokedGuestCredentialsFailClosedInsteadOfResettingBalance() async throws {
        let (store, tokens) = try makeStore(activeGuest: true)
        store.logout()
        RecoveryURLProtocol.state.refreshStatus = 401
        let balance = await store.bootstrapGuestIfNeeded()
        XCTAssertNil(balance)
        XCTAssertNil(store.session)
        XCTAssertNotNil(try tokens.loadGuestRecovery())
        XCTAssertFalse(RecoveryURLProtocol.state.paths.contains("/auth/guest"))
    }

    func testDifferentRecoveredUserCannotReplaceOriginalGuest() async throws {
        let (store, tokens) = try makeStore(activeGuest: true)
        store.logout()
        RecoveryURLProtocol.state.returnedGuestID = "different-guest"
        let balance = await store.bootstrapGuestIfNeeded()
        XCTAssertNil(balance)
        XCTAssertNil(store.session)
        XCTAssertEqual(try tokens.loadGuestRecovery()?.user.id, "original-guest")
        XCTAssertEqual(try tokens.loadGuestRecovery()?.refreshToken, "original-refresh")
        XCTAssertFalse(RecoveryURLProtocol.state.paths.contains("/auth/guest"))
    }

    func testLogoutDuringArchivedRecoveryKeepsRotatedCredentialsWithoutSigningIn() async throws {
        let (store, tokens) = try makeStore(activeGuest: true)
        store.logout()
        let refreshStarted = expectation(description: "Archived recovery sent")
        RecoveryURLProtocol.state.refreshStarted = { refreshStarted.fulfill() }
        RecoveryURLProtocol.state.refreshDelay = 0.2
        let recovery = Task { await store.bootstrapGuestIfNeeded() }
        await fulfillment(of: [refreshStarted], timeout: 3)
        store.logout()
        let balance = await recovery.value
        XCTAssertNil(balance)
        XCTAssertNil(store.session)
        XCTAssertNil(tokens.load())
        XCTAssertEqual(try tokens.loadGuestRecovery()?.refreshToken, "rotated-refresh")
    }

    func testCorruptGuestArchiveDoesNotCreateReplacementGuest() async throws {
        let (store, tokens) = try makeStore(activeGuest: true)
        store.logout()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: RecoveryURLProtocol.state.keychainService,
            kSecAttrAccount as String: "guest-recovery-session",
        ]
        XCTAssertEqual(SecItemUpdate(query as CFDictionary, [kSecValueData as String: Data("broken".utf8)] as CFDictionary), errSecSuccess)
        let balance = await store.bootstrapGuestIfNeeded()
        XCTAssertNil(balance)
        XCTAssertTrue(RecoveryURLProtocol.state.paths.isEmpty)
        XCTAssertThrowsError(try tokens.loadGuestRecovery())
    }

    func testLogoutDuringRefreshDoesNotSignBackInAndRetainsRotatedRecovery() async throws {
        let (store, tokens) = try makeStore(activeGuest: true)
        let refreshStarted = expectation(description: "Refresh sent")
        RecoveryURLProtocol.state.refreshStarted = { refreshStarted.fulfill() }
        RecoveryURLProtocol.state.refreshDelay = 0.2
        let refresh = Task { await store.restorePersistedSession() }
        await fulfillment(of: [refreshStarted], timeout: 3)
        store.logout()
        await refresh.value

        XCTAssertNil(store.session)
        XCTAssertNil(tokens.load())
        XCTAssertEqual(try tokens.loadGuestRecovery()?.refreshToken, "rotated-refresh")
    }

    func testDeleteAccountRemovesGuestRecoveryCredentials() async throws {
        let (store, tokens) = try makeStore(activeGuest: true)
        store.logout()
        _ = await store.bootstrapGuestIfNeeded()
        let deleted = await store.deleteAccount()
        XCTAssertTrue(deleted)
        XCTAssertNil(store.session)
        XCTAssertNil(tokens.load())
        XCTAssertNil(try tokens.loadGuestRecovery())
    }

    func testUpgradeCannotResurrectFormerGuestAfterMemberLogout() async throws {
        let (store, tokens) = try makeStore(activeGuest: true)
        store.logout()
        _ = await store.bootstrapGuestIfNeeded()
        await store.login(email: "member@example.com", password: "password")
        XCTAssertFalse(try XCTUnwrap(store.session).user.isAnonymous)
        XCTAssertNil(try tokens.loadGuestRecovery())
        store.logout()
        XCTAssertNil(try tokens.loadGuestRecovery())
    }

    func testLoginToSeparateMemberAccountKeepsUnmergedGuestBalanceRecoverable() async throws {
        let (store, tokens) = try makeStore(activeGuest: true)
        store.logout()
        _ = await store.bootstrapGuestIfNeeded()
        RecoveryURLProtocol.state.returnedMemberID = "separate-member"
        await store.login(email: "member@example.com", password: "password")
        XCTAssertEqual(store.session?.user.id, "separate-member")
        XCTAssertEqual(try tokens.loadGuestRecovery()?.user.id, "original-guest")
        store.logout()
        let remainingBalance = await store.bootstrapGuestIfNeeded()
        XCTAssertEqual(remainingBalance, 2)
        XCTAssertEqual(store.session?.user.id, "original-guest")
        store.logout()
    }

    func testStartupRefreshMigratesExistingGuestAndRotatesArchive() async throws {
        let (store, tokens) = try makeStore(activeGuest: true)
        XCTAssertNil(try tokens.loadGuestRecovery())
        await store.restorePersistedSession()
        XCTAssertEqual(tokens.load()?.refreshToken, "rotated-refresh")
        XCTAssertEqual(try tokens.loadGuestRecovery()?.refreshToken, "rotated-refresh")
        store.logout()
    }

    func testAnonymousStartupChecksDeviceWelcomeAndKeepsLegacyRemainingBalance() async throws {
        let (store, _) = try makeStore(activeGuest: true)
        await store.bootstrap()
        XCTAssertEqual(store.session?.user.id, "original-guest")
        XCTAssertTrue(RecoveryURLProtocol.state.paths.contains("/auth/guest/welcome"))
        XCTAssertFalse(RecoveryURLProtocol.state.paths.contains("/auth/guest"))
        let balance = await store.fetchThreadBalance()
        XCTAssertEqual(balance, 2)
        store.logout()
    }

    func testLogoutDuringStartupDoesNotCreateOrClaimAnotherGuest() async throws {
        let (store, tokens) = try makeStore(activeGuest: true)
        let healthStarted = expectation(description: "Startup health sent")
        RecoveryURLProtocol.state.healthStarted = { healthStarted.fulfill() }
        RecoveryURLProtocol.state.healthDelay = 0.2
        let startup = Task { await store.bootstrap() }
        await fulfillment(of: [healthStarted], timeout: 3)
        store.logout()
        await startup.value
        XCTAssertNil(store.session)
        XCTAssertNil(tokens.load())
        XCTAssertFalse(RecoveryURLProtocol.state.paths.contains("/auth/guest/welcome"))
        XCTAssertFalse(RecoveryURLProtocol.state.paths.contains("/auth/guest"))
    }

    private func makeStore(activeGuest: Bool) throws -> (CoorditBackendSessionStore, CoorditBackendTokenStore) {
        RecoveryURLProtocol.state.reset()
        let service = "app.coordit.guest-recovery-tests.\(UUID().uuidString)"
        RecoveryURLProtocol.state.keychainService = service
        let tokens = CoorditBackendTokenStore(service: service)
        if activeGuest {
            try tokens.save(CoorditAuthSession(
                accessToken: "original-access",
                refreshToken: "original-refresh",
                user: CoorditAuthUser(id: "original-guest", email: "guest@example.com", isAnonymous: true)
            ))
        }
        addTeardownBlock {
            tokens.delete()
            try tokens.deleteGuestRecovery()
        }
        return (CoorditBackendSessionStore(client: client(), tokenStore: tokens, deviceTokenProvider: { "unit-test-device-token" }), tokens)
    }

    private func client() -> CoorditBackendClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RecoveryURLProtocol.self]
        return CoorditBackendClient(baseURL: URL(string: "https://guest-recovery.invalid")!, session: URLSession(configuration: configuration))
    }
}

@MainActor
final class CoorditGuestReinstallProbeTests: XCTestCase {
    func testExplicitUninstallReinstallProbe() async throws {
        let phase = ProcessInfo.processInfo.environment["COORDIT_GUEST_REINSTALL_PHASE"]
        let service = "app.coordit.guest-recovery-tests.explicit-reinstall-probe"
        let userID = "00000000-0000-4000-8000-000000000099"
        let markerKey = "coordit.guest-reinstall-probe-container-marker"
        let tokens = CoorditBackendTokenStore(service: service)
        RecoveryURLProtocol.state.reset()
        RecoveryURLProtocol.state.returnedGuestID = userID
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RecoveryURLProtocol.self]
        let client = CoorditBackendClient(
            baseURL: URL(string: "https://guest-recovery.invalid")!,
            session: URLSession(configuration: configuration)
        )

        switch phase {
        case "seed":
            tokens.delete()
            try tokens.deleteGuestRecovery()
            try tokens.save(CoorditAuthSession(
                accessToken: "reinstall-probe-access",
                refreshToken: "reinstall-probe-refresh",
                user: CoorditAuthUser(id: userID, email: "reinstall-probe@guest.coordit.invalid", isAnonymous: true)
            ))
            let store = CoorditBackendSessionStore(client: client, tokenStore: tokens)
            store.logout()
            XCTAssertNil(tokens.load())
            XCTAssertEqual(try tokens.loadGuestRecovery()?.user.id, userID)
            UserDefaults.standard.set(true, forKey: markerKey)
            XCTAssertTrue(UserDefaults.standard.bool(forKey: markerKey))
            print("REINSTALL_PROBE_SEEDED user=\(userID) sandbox=\(NSHomeDirectory())")
        case "recover":
            defer {
                tokens.delete()
                try? tokens.deleteGuestRecovery()
                UserDefaults.standard.removeObject(forKey: markerKey)
            }
            XCTAssertNil(UserDefaults.standard.object(forKey: markerKey), "The seed app sandbox must have been removed by actual uninstall.")
            XCTAssertNil(tokens.load())
            let archived = try XCTUnwrap(tokens.loadGuestRecovery(), "The guest Keychain entry must survive app uninstall.")
            XCTAssertEqual(archived.user.id, userID)
            XCTAssertEqual(archived.refreshToken, "reinstall-probe-refresh")
            let store = CoorditBackendSessionStore(client: client, tokenStore: tokens)
            let balance = await store.bootstrapGuestIfNeeded()
            XCTAssertEqual(store.session?.user.id, userID)
            XCTAssertEqual(balance, 2)
            XCTAssertEqual(try tokens.loadGuestRecovery()?.refreshToken, "rotated-refresh")
            XCTAssertFalse(RecoveryURLProtocol.state.paths.contains("/auth/guest"))
            store.logout()
            print("REINSTALL_PROBE_RECOVERED user=\(userID) balance=\(balance ?? -1) sandbox=\(NSHomeDirectory())")
        default:
            XCTFail("Run the explicit probe scheme with TEST_RUNNER_COORDIT_GUEST_REINSTALL_PHASE=seed, uninstall the app, then run with recover.")
        }
    }
}

private final class RecoveryHTTPState: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedPaths: [String] = []
    private var storedKeychainService = ""
    private var storedRefreshStatus = 200
    private var storedGuestID = "original-guest"
    private var storedMemberID = "original-guest"
    private var storedRefreshDelay: TimeInterval = 0
    private var storedRefreshStarted: (() -> Void)?
    private var storedHealthStarted: (() -> Void)?
    private var storedHealthDelay: TimeInterval = 0

    var keychainService: String {
        get { lock.withLock { storedKeychainService } }
        set { lock.withLock { storedKeychainService = newValue } }
    }

    var refreshStatus: Int {
        get { lock.withLock { storedRefreshStatus } }
        set { lock.withLock { storedRefreshStatus = newValue } }
    }

    var returnedGuestID: String {
        get { lock.withLock { storedGuestID } }
        set { lock.withLock { storedGuestID = newValue } }
    }

    var returnedMemberID: String {
        get { lock.withLock { storedMemberID } }
        set { lock.withLock { storedMemberID = newValue } }
    }

    var refreshDelay: TimeInterval {
        get { lock.withLock { storedRefreshDelay } }
        set { lock.withLock { storedRefreshDelay = newValue } }
    }

    var refreshStarted: (() -> Void)? {
        get { lock.withLock { storedRefreshStarted } }
        set { lock.withLock { storedRefreshStarted = newValue } }
    }

    var healthStarted: (() -> Void)? {
        get { lock.withLock { storedHealthStarted } }
        set { lock.withLock { storedHealthStarted = newValue } }
    }

    var healthDelay: TimeInterval {
        get { lock.withLock { storedHealthDelay } }
        set { lock.withLock { storedHealthDelay = newValue } }
    }

    var paths: [String] {
        lock.lock()
        defer { lock.unlock() }
        return recordedPaths
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        recordedPaths = []
        storedRefreshStatus = 200
        storedGuestID = "original-guest"
        storedMemberID = "original-guest"
        storedRefreshDelay = 0
        storedRefreshStarted = nil
        storedHealthStarted = nil
        storedHealthDelay = 0
    }

    func record(_ path: String) {
        lock.lock()
        defer { lock.unlock() }
        recordedPaths.append(path)
    }
}

private final class RecoveryURLProtocol: URLProtocol, @unchecked Sendable {
    static let state = RecoveryHTTPState()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let path = request.url!.path
        Self.state.record(path)
        let status = path == "/auth/refresh" ? Self.state.refreshStatus : 200
        let body: String
        switch path {
        case "/health":
            Self.state.healthStarted?()
            body = #"{"ok":true,"service":"coordit-test"}"#
        case "/auth/refresh":
            Self.state.refreshStarted?()
            body = status == 200
                ? #"{"accessToken":"rotated-access","refreshToken":"rotated-refresh","user":{"id":"\#(Self.state.returnedGuestID)","email":"guest@example.com","isAnonymous":true}}"#
                : #"{"message":"Recovery unavailable"}"#
        case "/auth/login":
            body = #"{"accessToken":"member-access","refreshToken":"member-refresh","user":{"id":"\#(Self.state.returnedMemberID)","email":"member@example.com","isAnonymous":false}}"#
        case "/thread-wallet/balance", "/auth/guest/welcome":
            body = #"{"availableThreads":2,"status":"already_granted"}"#
        case "/thread-wallet/monetization-readiness":
            body = #"{"rewardedAdsEnabled":true,"iapEnabled":true}"#
        case "/users/me":
            body = #"{"id":"original-guest","email":"member@example.com","created_at":"2026-01-01","updated_at":"2026-01-01"}"#
        case "/body-measurements":
            body = "[]"
        case "/auth/onboarding/status":
            body = #"{"onboardingComplete":true}"#
        default:
            XCTFail("Unexpected recovery request: \(path)")
            body = "{}"
        }
        let delay = path == "/auth/refresh" ? Self.state.refreshDelay : path == "/health" ? Self.state.healthDelay : 0
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [self] in
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
    }
}
#endif
