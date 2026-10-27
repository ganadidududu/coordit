import XCTest
import UIKit
@testable import coordit

@MainActor
final class CoorditGarmentMeasurementTests: XCTestCase {
    func testMotionGuidanceUsesGravityMovementAndStableSamples() {
        XCTAssertEqual(CoorditCameraPosture.evaluate(gravityZ: -1, rotation: 0, acceleration: 0), .ready)
        XCTAssertEqual(CoorditCameraPosture.evaluate(gravityZ: 1, rotation: 0, acceleration: 0), .tilted)
        XCTAssertEqual(CoorditCameraPosture.evaluate(gravityZ: -0.9, rotation: 0, acceleration: 0), .tilted)
        XCTAssertEqual(CoorditCameraPosture.evaluate(gravityZ: -1, rotation: 0.4, acceleration: 0), .moving)
        XCTAssertEqual(CoorditCameraPosture.evaluate(gravityZ: -1, rotation: 0, acceleration: 0.1), .moving)
        let motion = CoorditCameraMotion()
        for _ in 0..<3 { motion.update(.ready) }
        XCTAssertEqual(motion.posture, .unavailable)
        motion.update(.ready)
        XCTAssertEqual(motion.posture, .ready)
        motion.update(.tilted)
        XCTAssertEqual(motion.posture, .ready)
        motion.stop()
        XCTAssertEqual(motion.posture, .unavailable)
    }

    func testManualPortraitCardUsesItsLongEdgeAndKeepsPhotoPoints() throws {
        let capture = CoorditGarmentCaptureController(method: .card)
        capture.setImage(cardScene(center: .init(x: 300, y: 180), angle: 90), detect: false)
        capture.beginManualCard()
        let card = [CoorditMeasurementPoint(x: 0.1, y: 0.1), .init(x: 0.2, y: 0.1),
                    .init(x: 0.2, y: 0.2268618007), .init(x: 0.1, y: 0.2268618007)]
        card.forEach(capture.tapImage)
        let calibration = try XCTUnwrap(capture.calibration)
        let longEdge = CoorditMeasurementSegment(start: try calibration.worldPoint(card[1]), end: try calibration.worldPoint(card[2]))
        XCTAssertEqual(longEdge.centimeters, 8.56, accuracy: 0.001)
    }

    func testCardWorksAtDifferentPositionsAndRotations() async throws {
        for (x, y, angle) in [(300.0, 2700.0, 0.0), (2070, 2700, 30), (300, 180, 90), (2100, 2050, -25), (250, 2050, 180)] {
            let capture = CoorditGarmentCaptureController(method: .card)
            capture.setImage(cardScene(center: CGPoint(x: x, y: y), angle: angle))
            for _ in 0..<300 where capture.isDetecting { try await Task.sleep(for: .milliseconds(50)) }
            XCTAssertTrue(capture.canReview, "card \(x),\(y),\(angle): \(capture.message ?? "missing detection")")
            XCTAssertEqual(capture.segments[.shoulder]?.centimeters ?? 0, 34.45, accuracy: 2)
            XCTAssertEqual(capture.segments[.length]?.centimeters ?? 0, 58.24, accuracy: 2, "card \(x),\(y),\(angle): \(capture.corners)")
        }
    }

    func testTapSelectsAmbiguousCardThenGarmentAndCorrectionRecalibrates() async throws {
        let capture = CoorditGarmentCaptureController(method: .card)
        capture.setImage(cardScene(center: CGPoint(x: 300, y: 2700), angle: 0, extraCard: true))
        for _ in 0..<300 where capture.isDetecting { try await Task.sleep(for: .milliseconds(50)) }
        XCTAssertTrue(capture.needsCardCorners)
        XCTAssertFalse(capture.canReview)
        capture.tapImage(.init(x: 300.0 / 2400, y: 2700.0 / 3000))
        for _ in 0..<300 where capture.isDetecting { try await Task.sleep(for: .milliseconds(50)) }
        XCTAssertTrue(capture.canReview, capture.message ?? "tap did not select card")
        let before = try XCTUnwrap(capture.segments[.chest]?.centimeters)
        let screen = capture.points.compactMap(capture.project)
        capture.select(.card)
        let corner = try XCTUnwrap(capture.corners.first)
        capture.moveCardCorner(0, to: .init(x: corner.x - 0.003, y: corner.y))
        XCTAssertNotEqual(capture.segments[.chest]?.centimeters, before)
        for (original, adjusted) in zip(screen, capture.points.compactMap(capture.project)) {
            XCTAssertEqual(original.x, adjusted.x, accuracy: 0.00001)
            XCTAssertEqual(original.y, adjusted.y, accuracy: 0.00001)
        }
        capture.select(.garment)
        capture.tapImage(.init(x: 0.5, y: 0.5))
        for _ in 0..<300 where capture.isDetecting { try await Task.sleep(for: .milliseconds(50)) }
        XCTAssertTrue(capture.canReview)
        XCTAssertEqual(capture.selection, .automatic)
        let valid = capture.corners
        capture.select(.card)
        capture.tapImage(.init(x: 0.5, y: 0.95))
        for _ in 0..<300 where capture.isDetecting { try await Task.sleep(for: .milliseconds(50)) }
        XCTAssertNotNil(capture.message)
        XCTAssertEqual(capture.corners.map(\.x), valid.map(\.x))
        XCTAssertTrue(capture.canReview)
    }

    private func cardScene(center: CGPoint, angle: Double, extraCard: Bool = false) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 2400, height: 3000), format: format).image { context in
            UIColor(white: 0.92, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2400, height: 3000))
            UIColor(white: 0.15, alpha: 1).setFill()
            context.cgContext.addPath(CoorditGarmentGuideShape(category: .tshirt).path(in: CGRect(x: 150, y: 100, width: 2100, height: 2300)).cgPath)
            context.cgContext.fillPath()
            context.cgContext.saveGState()
            context.cgContext.translateBy(x: center.x, y: center.y)
            context.cgContext.rotate(by: angle * .pi / 180)
            UIColor.black.setFill()
            UIBezierPath(roundedRect: CGRect(x: -120, y: -240 * 53.98 / 85.60 / 2, width: 240, height: 240 * 53.98 / 85.60), cornerRadius: 8).fill()
            context.cgContext.restoreGState()
            if extraCard {
                UIColor.black.setFill()
                UIBezierPath(roundedRect: CGRect(x: 1900, y: 2600, width: 240, height: 240 * 53.98 / 85.60), cornerRadius: 8).fill()
            }
        }
    }

    func testEveryExistingCategoryDetectsCardAndProducesItsMeasurements() async throws {
        for category in CoorditFitLabCategory.allCases {
            let capture = CoorditGarmentCaptureController(method: .card)
            capture.configure(category: category)
            capture.loadGuideTestFixture()
            for _ in 0..<200 where capture.isDetecting { try await Task.sleep(for: .milliseconds(50)) }
            XCTAssertFalse(capture.isDetecting, category.rawValue)
            XCTAssertEqual(capture.corners.count, 4, category.rawValue)
            XCTAssertTrue(capture.hasAutomaticProposal, "\(category): \(capture.message ?? "no proposal")")
            XCTAssertEqual(capture.points.count, category == .skirt ? 6 : 8, category.rawValue)
            if capture.hasAutomaticProposal {
                capture.basisConfirmed = true
                let result = try capture.makeMeasurement()
                XCTAssertEqual(result.resolvedCategory, category)
                XCTAssertEqual(result.measurementValues.count, category == .skirt ? 3 : 4)
                if category == .skirt {
                    XCTAssertNil(result.clothingSizeRequest.rise)
                    XCTAssertNotNil(result.clothingSizeRequest.totalLength)
                    XCTAssertNil(result.clothingSizeRequest.outseam)
                }
                if [.pants, .jeans, .shorts].contains(category) {
                    XCTAssertEqual(result.measurementValues["waist_width"] ?? 0, 38.3, accuracy: 2, category.rawValue)
                    XCTAssertEqual(result.measurementValues["outseam"] ?? 0, category == .shorts ? 50.1 : 72.0, accuracy: 2, category.rawValue)
                }
                if category.garmentKind == .upper {
                    XCTAssertEqual(result.measurementValues["shoulder_width"] ?? 0, 34.45, accuracy: 2, category.rawValue)
                    XCTAssertEqual(result.measurementValues["total_length"] ?? 0, category == .coat ? 66.45 : 58.24, accuracy: 2, category.rawValue)
                }
            }
            if category == .hoodie {
                let attachment = XCTAttachment(image: try XCTUnwrap(capture.image))
                attachment.name = "hoodie-source"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }

    func testLongSleeveTShirtUsesSameCategoryAndMeasuresLongerSleeve() async throws {
        let capture = CoorditGarmentCaptureController(method: .card)
        capture.longSleeves = true
        capture.loadGuideTestFixture()
        for _ in 0..<200 where capture.isDetecting { try await Task.sleep(for: .milliseconds(50)) }
        XCTAssertTrue(capture.hasAutomaticProposal, capture.message ?? "no proposal")
        XCTAssertEqual(capture.category, .tshirt)
        XCTAssertEqual(capture.segments[.sleeve]?.centimeters ?? 0, 37.4, accuracy: 2)
    }

    func testLegacyMeasurementDecodesWithoutCategoryAndCategorySwitchCancelsDetection() async throws {
        let capture = CoorditGarmentCaptureController(method: .card)
        capture.loadTestFixture()
        let original = try capture.makeMeasurement()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        json.removeValue(forKey: "category")
        let restored = try JSONDecoder().decode(CoorditGarmentMeasurement.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(restored.resolvedCategory, .tshirt)
        capture.loadGuideTestFixture()
        capture.configure(category: .hoodie)
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertTrue(capture.points.isEmpty)
        XCTAssertNil(capture.image)
        XCTAssertFalse(capture.isDetecting)
        XCTAssertEqual(capture.category, .hoodie)
    }

    func testMissingCardDoesNotInventMeasurements() async throws {
        let capture = CoorditGarmentCaptureController(method: .card)
        let blank = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 1500)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1200, height: 1500))
        }
        capture.setImage(blank)
        for _ in 0..<200 where capture.isDetecting { try await Task.sleep(for: .milliseconds(50)) }
        XCTAssertTrue(capture.needsCardCorners)
        XCTAssertFalse(capture.canReview)
        XCTAssertTrue(capture.points.isEmpty)
    }

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
    func testSkirtCameraRegistrationPreservesLengthAndClearsTrouserFields() throws {
        let segment: (Double) -> CoorditMeasurementSegment = { .init(start: .init(x: 0, y: 0), end: .init(x: $0 / 100, y: 0)) }
        let measurement = try CoorditGarmentMeasurement(method: .card, segments: [
            .waist: segment(35), .hip: segment(48), .length: segment(72)
        ], lengthBasis: "waist_to_hem", category: .skirt)
        var draft = CoorditClosetDraft()
        draft.measurement4 = "old-trouser-outseam"
        draft.applyCameraMeasurement(measurement, photo: Data([1, 2]))
        XCTAssertEqual(draft.exactCategory, .skirt)
        XCTAssertEqual(Double(draft.measurement3), 72)
        XCTAssertEqual(draft.measurement4, "")
        XCTAssertNil(measurement.clothingSizeRequest.rise)
        XCTAssertNil(measurement.clothingSizeRequest.outseam)
        XCTAssertEqual(measurement.clothingSizeRequest.totalLength, 72)
        XCTAssertEqual(draft.garmentImageData, Data([1, 2]))
    }

}
