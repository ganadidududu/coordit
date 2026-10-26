import Foundation
import Security

#if os(iOS)
struct CoorditBackendTokenStore {
    private let service: String
    private let account = "auth-session"
    private let guestRecoveryAccount = "guest-recovery-session"

    init(service: String = "app.coordit.backend") {
        self.service = service
    }

    func load() -> CoorditAuthSession? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        guard let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(CoorditAuthSession.self, from: data)
    }

    func save(_ session: CoorditAuthSession) throws {
        try save(session, account: account)
    }

    func loadGuestRecovery() throws -> CoorditAuthSession? {
        var query = baseQuery(account: guestRecoveryAccount)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw TokenStoreError.unavailable
        }
        let session = try JSONDecoder().decode(CoorditAuthSession.self, from: data)
        guard session.user.isAnonymous else { throw TokenStoreError.unavailable }
        return session
    }

    func saveGuestRecovery(_ session: CoorditAuthSession) throws {
        guard session.user.isAnonymous else { throw TokenStoreError.unavailable }
        try save(session, account: guestRecoveryAccount)
    }

    func deleteGuestRecovery() throws {
        let status = SecItemDelete(baseQuery(account: guestRecoveryAccount) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw TokenStoreError.unavailable
        }
    }

    private func save(_ session: CoorditAuthSession, account: String) throws {
        let query = baseQuery(account: account)
        let data = try JSONEncoder().encode(session)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else { throw TokenStoreError.unavailable }

        var newItem = query
        attributes.forEach { key, value in newItem[key] = value }
        guard SecItemAdd(newItem as CFDictionary, nil) == errSecSuccess else {
            throw TokenStoreError.unavailable
        }
    }

    func delete() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private var baseQuery: [String: Any] {
        baseQuery(account: account)
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

enum TokenStoreError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "로그인 정보를 안전하게 저장하지 못했어요."
    }
}
#endif
