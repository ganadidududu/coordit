import XCTest
@testable import coordit

@MainActor
final class CoorditFirstUseGuidanceTests: XCTestCase {
    func testGuidanceFinishesEachFeatureOnceAndIsIsolatedByAccount() throws {
        let suite = "first-use-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let guidance = CoorditFirstUseGuidance(defaults: defaults)
        guidance.prepare(userID: "alice")
        XCTAssertEqual(guidance.presentedGuide, .fitLab)
        guidance.begin(.fitLab)
        XCTAssertNil(guidance.presentedGuide)
        XCTAssertEqual(guidance.activePractice, .fitLab)
        guidance.finish(.fitLab)
        XCTAssertEqual(guidance.presentedGuide, .closet)
        guidance.finish(.closet)
        XCTAssertNil(guidance.presentedGuide)

        let relaunched = CoorditFirstUseGuidance(defaults: defaults)
        relaunched.prepare(userID: "alice")
        XCTAssertNil(relaunched.presentedGuide)
        relaunched.prepare(userID: "bob")
        XCTAssertEqual(relaunched.presentedGuide, .fitLab)
        relaunched.prepare(userID: nil)
        XCTAssertNil(relaunched.presentedGuide)
        XCTAssertNil(relaunched.activePractice)
    }

    func testInterruptedPracticeRemainsPendingOnNextLaunch() throws {
        let suite = "first-use-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let guidance = CoorditFirstUseGuidance(defaults: defaults)
        guidance.prepare(userID: "alice")
        guidance.finish(.fitLab)
        guidance.begin(.closet)
        let relaunched = CoorditFirstUseGuidance(defaults: defaults)
        relaunched.prepare(userID: "alice")
        XCTAssertEqual(relaunched.presentedGuide, .closet)
    }
}
