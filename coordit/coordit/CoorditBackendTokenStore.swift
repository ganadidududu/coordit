import Foundation
import Security

#if os(iOS)
struct CoorditBackendTokenStore {
    private let service = "app.coordit.backend"
    private let account = "auth-session"

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
        let data = try JSONEncoder().encode(session)
        delete()

        var query = baseQuery
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw TokenStoreError.unavailable }
    }

    func delete() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private var baseQuery: [String: Any] {
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
