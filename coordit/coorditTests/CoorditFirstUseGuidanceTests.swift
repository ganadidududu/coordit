import XCTest
@testable import coordit

@MainActor
final class CoorditFirstUseGuidanceTests: XCTestCase {
    func testPreparingAccountDoesNotStartPracticeAndFeaturesAreIndependent() throws {
        let suite = "first-use-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let guidance = CoorditFirstUseGuidance(defaults: defaults)
        guidance.prepare(userID: "alice")
        XCTAssertNil(guidance.activePractice)
        XCTAssertTrue(guidance.needsPractice(.fitLab))
        XCTAssertTrue(guidance.needsPractice(.closet))
        guidance.begin(.closet)
        XCTAssertEqual(guidance.activePractice, .closet)
        guidance.finish(.closet)
        XCTAssertNil(guidance.activePractice)
        XCTAssertTrue(guidance.needsPractice(.fitLab))
        XCTAssertFalse(guidance.needsPractice(.closet))
        guidance.begin(.fitLab)
        guidance.markCompleted(.closet)
        XCTAssertEqual(guidance.activePractice, .fitLab)
        guidance.finish(.fitLab)
        XCTAssertNil(guidance.activePractice)
        let relaunched = CoorditFirstUseGuidance(defaults: defaults)
        relaunched.prepare(userID: "alice")
        XCTAssertFalse(relaunched.needsPractice(.fitLab))
        XCTAssertFalse(relaunched.needsPractice(.closet))
        relaunched.prepare(userID: "bob")
        XCTAssertNil(relaunched.activePractice)
        XCTAssertTrue(relaunched.needsPractice(.fitLab))
        relaunched.prepare(userID: nil)
        XCTAssertFalse(relaunched.needsPractice(.fitLab))
        XCTAssertNil(relaunched.activePractice)
    }

    func testInterruptedPracticeStaysPendingAndAccountChangesClearActivePractice() throws {
        let suite = "first-use-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let guidance = CoorditFirstUseGuidance(defaults: defaults)
        guidance.prepare(userID: "alice")
        guidance.begin(.fitLab)
        let relaunched = CoorditFirstUseGuidance(defaults: defaults)
        relaunched.prepare(userID: "alice")
        XCTAssertNil(relaunched.activePractice)
        XCTAssertTrue(relaunched.needsPractice(.fitLab))
        guidance.prepare(userID: "bob")
        XCTAssertNil(guidance.activePractice)
        XCTAssertTrue(guidance.needsPractice(.fitLab))
    }
    func testReplayIsolatesReferencesAndRestoresRealAnalysisAndCheckpoint() async throws {
        let api = CoorditFitLabFixtureAPI(fixtureName: "url-success")
        let coordinator = CoorditFitLabCoordinator(route: .fitLabInput,
            configuration: .init(name: "url-success", userID: "practice-user", historyRootDirectory: nil, resetsHistory: false), api: api)
        coordinator.draft = CoorditFitLabDraft(source: .url, productName: "원래 상품",
            productURL: URL(string: "https://shop.example/original"), sizes: [
                .init(label: "M", measurements: [.shoulderWidth: 45, .chestWidth: 52, .totalLength: 68, .sleeveLength: 22])
            ], isSourceConfirmed: true)
        await coordinator.loadCompatibleReferences()
        let reference = try XCTUnwrap(coordinator.references.first)
        XCTAssertTrue(coordinator.selectReference(id: reference.id))
        coordinator.isComparisonRequested = true
        await coordinator.submit()
        let recommendation = try XCTUnwrap(coordinator.recommendation)
        let draft = coordinator.draft
        let checkpoint = coordinator.checkpoint
        let references = coordinator.references.map(\.id)
        let ledger = api.requestLedger
        XCTAssertTrue(coordinator.beginTutorialPractice())
        XCTAssertTrue(coordinator.references.isEmpty)
        XCTAssertNil(coordinator.recommendation)
        XCTAssertFalse(coordinator.isComparisonRequested)
        coordinator.draft.sizes = draft.sizes
        coordinator.draft.productName = "예시 상품"
        coordinator.draft.isSourceConfirmed = true
        coordinator.registerTutorialReference()
        XCTAssertEqual(coordinator.draft.selectedReferenceIDs, ["tutorial-reference"])
        XCTAssertTrue(coordinator.isComparisonRequested)
        XCTAssertTrue(coordinator.canSubmit)
        await coordinator.submit()
        XCTAssertEqual(coordinator.recommendation?.fitAnalysisResultID, "tutorial-example")
        XCTAssertEqual(api.requestLedger, ledger)
        coordinator.discardAndRestart()
        XCTAssertEqual(coordinator.draft, draft)
        XCTAssertEqual(coordinator.references.map(\.id), references)
        XCTAssertEqual(coordinator.checkpoint, checkpoint)
        XCTAssertEqual(coordinator.recommendation?.fitAnalysisResultID, recommendation.fitAnalysisResultID)
        XCTAssertTrue(coordinator.isComparisonRequested)
    }

    func testClosetPracticeIgnoresStaleOverviewAndTracksLinkStages() throws {
        let suite = "closet-practice-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let tutorial = CoorditClosetTutorial(defaults: defaults)
        tutorial.requiresSkipConfirmation = true
        tutorial.restart()
        tutorial.advance(from: .add, to: .method)
        var draft = CoorditClosetDraft()
        tutorial.updateLink(CoorditTutorialExample.link)
        tutorial.visit(.closetOverview, draft: draft)
        XCTAssertEqual(tutorial.step, .analyze)
        draft.productLink = CoorditTutorialExample.link
        draft.extractedSizeRows = [.init(label: "M", measurements: [.chestWidth: 52])]
        tutorial.visit(.closetAddLink, draft: draft)
        XCTAssertEqual(tutorial.step, .size)
        draft.selectedSizeRowID = draft.extractedSizeRows[0].id
        tutorial.visit(.closetAddLink, draft: draft)
        XCTAssertEqual(tutorial.step, .register)
    }

}
