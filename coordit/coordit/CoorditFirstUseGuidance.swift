import Foundation
import Combine

#if os(iOS)
@MainActor
final class CoorditFirstUseGuidance: ObservableObject {
    @Published var presentedGuide: CoorditUsageGuide?
    @Published private(set) var activePractice: CoorditUsageGuide?
    private let defaults: UserDefaults
    private var userID: String?

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func prepare(userID: String?) {
        guard self.userID != userID else { return }
        self.userID = userID
        activePractice = nil
        presentedGuide = userID == nil ? nil : nextGuide
    }

    func begin(_ guide: CoorditUsageGuide) {
        guard userID != nil else { return }
        presentedGuide = nil
        activePractice = guide
    }

    func finish(_ guide: CoorditUsageGuide) {
        guard let userID else { return }
        defaults.set(true, forKey: key(userID, guide))
        activePractice = nil
        presentedGuide = nextGuide
    }

    private var nextGuide: CoorditUsageGuide? {
        guard let userID else { return nil }
        return [CoorditUsageGuide.fitLab, .closet].first { !defaults.bool(forKey: key(userID, $0)) }
    }

    private func key(_ userID: String, _ guide: CoorditUsageGuide) -> String {
        "coordit.firstUseGuidance.v1.\(userID).\(guide.rawValue)"
    }
}
#endif
