import XCTest
@testable import coordit

@MainActor
final class CoorditGarmentMeasurementTests: XCTestCase {
    func testOnlyCompletePlausibleImportsSkipReview() {
        let valid = CoorditFitLabSizeDraft(label: "M", measurements: [.shoulderWidth: 45, .chestWidth: 54, .totalLength: 70, .sleeveLength: 22])
        XCTAssertTrue(CoorditFitLabImportAcceptance.canContinue(sizes: [valid], kind: .upper))
        let missing = CoorditFitLabSizeDraft(label: "M", measurements: [.chestWidth: 54])
        XCTAssertFalse(CoorditFitLabImportAcceptance.canContinue(sizes: [missing], kind: .upper))
        var invalid = valid
        invalid.measurements[.chestWidth] = 999
        XCTAssertFalse(CoorditFitLabImportAcceptance.canContinue(sizes: [invalid], kind: .upper))
        var duplicate = valid
        duplicate.label = "ｍ"
        XCTAssertFalse(CoorditFitLabImportAcceptance.canContinue(sizes: [valid, duplicate], kind: .upper))
    }

    func testVisionProposesCardAndShirtPointsWithoutSeededCoordinates() async throws {
        let capture = CoorditGarmentCaptureController(method: .card)
        capture.loadTestFixture(automatic: true)
        for _ in 0..<200 where capture.isDetecting { try await Task.sleep(for: .milliseconds(100)) }
        XCTAssertFalse(capture.isDetecting)
        XCTAssertEqual(capture.corners.count, 4)
        XCTAssertTrue(capture.hasAutomaticProposal, capture.message ?? "No proposal")
        XCTAssertEqual(capture.points.count, 8)
        XCTAssertEqual(capture.segments[.chest]?.centimeters ?? 0, 27, accuracy: 1)
        XCTAssertEqual(capture.segments[.length]?.centimeters ?? 0, 51.5, accuracy: 2)
        XCTAssertEqual(capture.segments[.shoulder]?.centimeters ?? 0, 35, accuracy: 2)
        XCTAssertEqual(capture.segments[.sleeve]?.centimeters ?? 0, 11.8, accuracy: 2)
        XCTAssertFalse(capture.canFinish)
        capture.basisConfirmed = true
        XCTAssertNoThrow(try capture.makeMeasurement())
        capture.moveEndpoint(0, to: .init(x: 0.22, y: 0.16))
        XCTAssertFalse(capture.basisConfirmed)
    }

    func testPantsSilhouetteProducesLowerMeasurementsAndRejectsPlainRectangle() throws {
        let polygon: [CoorditMeasurementPoint] = [.init(x: 0.25, y: 0.1), .init(x: 0.75, y: 0.1), .init(x: 0.8, y: 0.3), .init(x: 0.75, y: 0.9), .init(x: 0.55, y: 0.9), .init(x: 0.5, y: 0.4), .init(x: 0.45, y: 0.9), .init(x: 0.25, y: 0.9), .init(x: 0.2, y: 0.3)]
        let proposal = try XCTUnwrap(CoorditGarmentOutlineDetector.landmarks(polygon))
        XCTAssertTrue(proposal.isLower)
        XCTAssertEqual(proposal.points.count, 8)
        let segments = Dictionary(uniqueKeysWithValues: CoorditGarmentDimension.lower.enumerated().map { index, dimension in
            (dimension, CoorditMeasurementSegment(start: .init(x: proposal.points[index * 2].x, y: proposal.points[index * 2].y), end: .init(x: proposal.points[index * 2 + 1].x, y: proposal.points[index * 2 + 1].y)))
        })
        let measurement = try CoorditGarmentMeasurement(method: .card, segments: segments, lengthBasis: "waist_to_hem")
        XCTAssertNotNil(measurement.clothingSizeRequest.waistWidth)
        XCTAssertNil(measurement.clothingSizeRequest.shoulderWidth)
        XCTAssertNil(CoorditGarmentOutlineDetector.landmarks([.init(x: 0.2, y: 0.1), .init(x: 0.8, y: 0.1), .init(x: 0.8, y: 0.9), .init(x: 0.2, y: 0.9)]))
    }

    func testResetDiscardsInFlightAutomaticDetection() async throws {
        let capture = CoorditGarmentCaptureController(method: .card)
        capture.loadTestFixture(automatic: true)
        capture.clearCapture()
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertNil(capture.image)
        XCTAssertTrue(capture.points.isEmpty)
        XCTAssertFalse(capture.isDetecting)
    }

    func testCardCalibrationMeasuresBeyondTheCardAndRoundTrips() throws {
        let corners = [CoorditMeasurementPoint(x: 0.10, y: 0.10), .init(x: 0.30, y: 0.10), .init(x: 0.30, y: 0.2261214953), .init(x: 0.10, y: 0.2261214953)]
        let calibration = try CoorditCardCalibration(corners: corners, imageWidth: 2000, imageHeight: 2000)
        let start = try calibration.worldPoint(.init(x: 0.1, y: 0.3))
        let end = try calibration.worldPoint(.init(x: 0.9, y: 0.3))
        XCTAssertEqual(CoorditMeasurementSegment(start: start, end: end).centimeters, 34.24, accuracy: 0.001)
        let restored = try XCTUnwrap(calibration.imagePoint(end))
        XCTAssertEqual(restored.x, 0.9, accuracy: 0.000001)
        XCTAssertEqual(restored.y, 0.3, accuracy: 0.000001)
    }

    func testPerspectiveCardPreservesItsPhysicalDiagonal() throws {
        let corners = [CoorditMeasurementPoint(x: 0.2, y: 0.2), .init(x: 0.65, y: 0.25), .init(x: 0.55, y: 0.6), .init(x: 0.25, y: 0.55)]
        let calibration = try CoorditCardCalibration(corners: corners, imageWidth: 1800, imageHeight: 2400)
        let diagonal = CoorditMeasurementSegment(start: try calibration.worldPoint(corners[0]), end: try calibration.worldPoint(corners[2]))
        XCTAssertEqual(diagonal.centimeters, hypot(8.56, 5.398), accuracy: 0.000001)
    }

    func testInvalidCrossedAndTinyCardsAreRejected() {
        let crossed = [CoorditMeasurementPoint(x: 0, y: 0), .init(x: 1, y: 1), .init(x: 1, y: 0), .init(x: 0, y: 1)]
        XCTAssertThrowsError(try CoorditCardCalibration(corners: crossed, imageWidth: 1000, imageHeight: 1000))
        let tiny = [CoorditMeasurementPoint(x: 0.1, y: 0.1), .init(x: 0.11, y: 0.1), .init(x: 0.11, y: 0.1063), .init(x: 0.1, y: 0.1063)]
        XCTAssertThrowsError(try CoorditCardCalibration(corners: tiny, imageWidth: 2000, imageHeight: 2000))
    }

    func testCandidateChestExpandsSymmetricallyButLengthKeepsItsOrigin() throws {
        let segment = CoorditMeasurementSegment(start: .init(x: 0, y: 0), end: .init(x: 0.5, y: 0))
        let centered = try XCTUnwrap(segment.resized(centimeters: 60, centered: true))
        XCTAssertEqual(centered.start.x, -0.05, accuracy: 0.000001)
        XCTAssertEqual(centered.end.x, 0.55, accuracy: 0.000001)
        let anchored = try XCTUnwrap(segment.resized(centimeters: 60, centered: false))
        XCTAssertEqual(anchored.start.x, 0)
        XCTAssertEqual(anchored.end.x, 0.6, accuracy: 0.000001)
    }

    func testIncompleteAndNonFiniteMeasurementsCannotBecomeAReference() {
        XCTAssertThrowsError(try CoorditGarmentMeasurement(method: .card, segments: [:], lengthBasis: "high_shoulder_to_hem"))
        let invalid = CoorditMeasurementSegment(start: .init(x: .nan, y: 0), end: .init(x: 0.5, y: 0))
        XCTAssertNil(invalid.resized(centimeters: 50, centered: true))
    }
}
