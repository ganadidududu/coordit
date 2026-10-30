import Foundation
import Combine

#if os(iOS)
@MainActor
final class CoorditFirstUseGuidance: ObservableObject {
    @Published private(set) var activePractice: CoorditUsageGuide?
    private let defaults: UserDefaults
    private var userID: String?

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func prepare(userID: String?) {
        guard self.userID != userID else { return }
        self.userID = userID
        activePractice = nil
    }

    func needsPractice(_ guide: CoorditUsageGuide) -> Bool {
        guard let userID, guide != .fitLabReferences else { return false }
        return !defaults.bool(forKey: key(userID, guide))
    }

    func begin(_ guide: CoorditUsageGuide) {
        guard activePractice == nil else { return }
        activePractice = guide
    }

    func markCompleted(_ guide: CoorditUsageGuide) {
        guard let userID else { return }
        defaults.set(true, forKey: key(userID, guide))
    }

    func finish(_ guide: CoorditUsageGuide) {
        markCompleted(guide)
        if activePractice == guide { activePractice = nil }
    }

    private func key(_ userID: String, _ guide: CoorditUsageGuide) -> String {
        "coordit.firstUseGuidance.v2.\(userID).\(guide.rawValue)"
    }
}
#endif
