import XCTest
@testable import coordit

@MainActor final class CoorditARFieldTestSessionTests: XCTestCase {
    private func configured() -> CoorditARFieldTestSession {
        let session = CoorditARFieldTestSession()
        session.garmentID = "field-fixture-not-real-evaluation"
        session.background = "test fixture"
        session.lighting = "generated"
        session.independent = true
        for dimension in CoorditGarmentDimension.upper { session.groundTruth[dimension.measurementKey] = "60" }
        return session
    }

    func testMissingTapeAndDuplicateAttemptCannotBeRecorded() throws {
        let capture = CoorditGarmentCaptureController(method: .card)
        capture.loadTestFixture()
        let session = configured()
        session.groundTruth = [:]
        XCTAssertThrowsError(try session.record(capture, stage: "automatic"))
        session.groundTruth = Dictionary(uniqueKeysWithValues: CoorditGarmentDimension.upper.map { ($0.measurementKey, "60") })
        try session.record(capture, stage: "automatic")
        XCTAssertThrowsError(try session.record(capture, stage: "automatic"))
        XCTAssertEqual(session.trials.count, 1)
    }

    func testManualCorrectionPreservesOriginalFailureAndFrameIdentity() throws {
        let capture = CoorditGarmentCaptureController(method: .card)
        capture.loadTestFixture()
        let session = configured()
        session.prepareAutomatic(capture)
        try session.record(capture, stage: "automatic")
        // The deterministic fixture is manually entered, so it must not become a fake automatic success.
        XCTAssertTrue(session.trials[0].measurements.allSatisfy { $0.predictedCm == nil })
        let p = try XCTUnwrap(capture.project(capture.points[0]))
        capture.moveEndpoint(0, to: .init(x: p.x + 0.01, y: p.y))
        try session.record(capture, stage: "manual")
        XCTAssertEqual(session.trials[0].attemptID, session.trials[1].attemptID)
        XCTAssertTrue(session.trials[1].measurements.allSatisfy { $0.predictedCm != nil })
        XCTAssertTrue(session.trials.allSatisfy(\.synthetic))
        let attachment = XCTAttachment(data: try session.encoded(), uniformTypeIdentifier: "public.json")
        attachment.name = "ar-field-export-simulator-fixture-not-real-cm.json"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testChangingTruthWithinOneFrameIsRefused() throws {
        let capture = CoorditGarmentCaptureController(method: .card)
        capture.loadTestFixture()
        let session = configured()
        try session.record(capture, stage: "automatic")
        session.groundTruth["chest_width"] = "61"
        XCTAssertThrowsError(try session.record(capture, stage: "manual"))
        XCTAssertEqual(session.trials.count, 1)
    }

    func testIncompleteManualCorrectionIsRecordedAsFailure() throws {
        let capture = CoorditGarmentCaptureController(method: .card)
        capture.loadTestFixture()
        let session = configured()
        try session.record(capture, stage: "automatic")
        capture.beginManualGarment()
        try session.record(capture, stage: "manual")
        XCTAssertTrue(session.trials[1].measurements.allSatisfy { $0.predictedCm == nil })
        XCTAssertNotNil(session.trials[1].failureReason)
    }
}
