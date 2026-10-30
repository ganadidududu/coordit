import Foundation

#if os(iOS)
struct CoorditLocalProfile {
    var bio = "나에게 꼭 맞는 핏을 찾고 있어요."
    var avatarIndex = 0

    static let avatarSymbols = ["person.crop.circle", "person.crop.circle.fill", "person.crop.square"]

}

struct CoorditLocalProfileStore {
    static func load(userID: String) -> CoorditLocalProfile {
        let values = UserDefaults.standard.dictionary(forKey: key(userID))
        let index = values?["avatarIndex"] as? Int ?? 0
        return CoorditLocalProfile(
            bio: values?["bio"] as? String ?? CoorditLocalProfile().bio,
            avatarIndex: CoorditLocalProfile.avatarSymbols.indices.contains(index) ? index : 0
        )
    }

    static func save(_ profile: CoorditLocalProfile, userID: String) {
        UserDefaults.standard.set(
            ["bio": profile.bio, "avatarIndex": profile.avatarIndex],
            forKey: key(userID)
        )
    }

    static func clear(userID: String) {
        UserDefaults.standard.removeObject(forKey: key(userID))
    }

    private static func key(_ userID: String) -> String {
        "coordit.local-profile.\(userID)"
    }
}
#endif
