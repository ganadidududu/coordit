import XCTest
import simd
@testable import coordit

@MainActor
final class CoorditHostedARTests: XCTestCase {
    private func geometry() -> CoorditARPlaneGeometry {
        var camera = matrix_identity_float4x4
        camera.columns.1 = SIMD4(0, 0, -1, 0)
        camera.columns.2 = SIMD4(0, 1, 0, 0)
        camera.columns.3 = SIMD4(0, 1, 0, 1)
        return .init(intrinsics: simd_float3x3(rows: [SIMD3(1000, 0, 500), SIMD3(0, 1000, 500), SIMD3(0, 0, 1)]),
            cameraTransform: camera, planeTransform: matrix_identity_float4x4,
            boundary: [SIMD2(-1, -1), SIMD2(1, -1), SIMD2(1, 1), SIMD2(-1, 1)],
            imageSize: SIMD2(1000, 1000), orientation: .up)
    }

    func testVisibleSeamsUseFrozenPlaneToCalculateCentimeters() throws {
        let pair = CoorditHostedSemantics.pairs(.tshirt)[0]
        let points = [CoorditHostedPoint(landmarkType: "shoulder_left", x: 0.25, y: 0.5, status: "visible_proposal"),
                      CoorditHostedPoint(landmarkType: "shoulder_right", x: 0.75, y: 0.5, status: "visible_proposal")]
        let segment = try XCTUnwrap(CoorditHostedSemantics.segment(pair, points: points, geometry: geometry()))
        XCTAssertEqual(segment.centimeters, 50, accuracy: 0.001)
    }

    func testUncertainAndMissingSeamsDoNotProduceCentimetersUntilCorrected() {
        let pair = CoorditHostedSemantics.pairs(.tshirt)[0]
        var points = [CoorditHostedPoint(landmarkType: "shoulder_left", x: 0.25, y: 0.5, status: "uncertain_proposal"),
                      CoorditHostedPoint(landmarkType: "shoulder_right", x: 0.75, y: 0.5, status: "visible_proposal")]
        XCTAssertNil(CoorditHostedSemantics.segment(pair, points: points, geometry: geometry()))
        points[0].status = "user_corrected"
        XCTAssertNotNil(CoorditHostedSemantics.segment(pair, points: points, geometry: geometry()))
        points.removeLast()
        XCTAssertNil(CoorditHostedSemantics.segment(pair, points: points, geometry: geometry()))
    }

    func testUncertainDraftHasPreviewButRequiresExplicitHumanReview() throws {
        let pair = CoorditHostedSemantics.pairs(.tshirt)[0]
        var points = [CoorditHostedPoint(landmarkType: "shoulder_left", x: 0.25, y: 0.5, status: "uncertain_proposal"),
                      CoorditHostedPoint(landmarkType: "shoulder_right", x: 0.75, y: 0.5, status: "visible_proposal")]
        let original = points
        let draft = try XCTUnwrap(CoorditHostedSemantics.segment(pair, points: points, geometry: geometry(), allowUncertainDraft: true))
        XCTAssertEqual(draft.centimeters, 50, accuracy: 0.001)
        XCTAssertNil(CoorditHostedSemantics.segment(pair, points: points, geometry: geometry()))
        XCTAssertFalse(CoorditHostedSemantics.userReviewed(pair, points: points))
        XCTAssertTrue(points[0].confirm(geometry: geometry()))
        XCTAssertFalse(CoorditHostedSemantics.userReviewed(pair, points: points))
        XCTAssertTrue(points[1].confirm(geometry: geometry()))
        XCTAssertTrue(CoorditHostedSemantics.userReviewed(pair, points: points))
        XCTAssertEqual(points[0].x, original[0].x)
        XCTAssertEqual(points[0].y, original[0].y)
        XCTAssertEqual(points[0].status, "user_confirmed")
        XCTAssertEqual(original[0].status, "uncertain_proposal")
    }

    func testConfirmPreservesCorrectionsAndCannotInventMissingOrInvalidPoints() {
        var corrected = CoorditHostedPoint(landmarkType: "shoulder_left", x: 0.25, y: 0.5, status: "user_corrected")
        XCTAssertTrue(corrected.confirm(geometry: geometry()))
        XCTAssertEqual(corrected.status, "user_corrected")
        var missing = CoorditHostedPoint(landmarkType: "shoulder_right", x: nil, y: nil, status: "abstain")
        XCTAssertFalse(missing.confirm(geometry: geometry()))
        XCTAssertNil(missing.position)
        var invalid = CoorditHostedPoint(landmarkType: "shoulder_right", x: 1.2, y: 0.5, status: "uncertain_proposal")
        XCTAssertFalse(invalid.confirm(geometry: geometry()))
        let pair = CoorditHostedSemantics.pairs(.tshirt)[0]
        XCTAssertNil(CoorditHostedSemantics.segment(pair, points: [corrected, missing], geometry: geometry(), allowUncertainDraft: true))
        XCTAssertNil(CoorditHostedSemantics.segment(pair, points: [corrected, invalid], geometry: geometry(), allowUncertainDraft: true))
    }

    func testDraftAndHumanConfirmationStillRejectOutsideFrozenPlane() {
        let base = geometry()
        let narrowPlane = CoorditARPlaneGeometry(intrinsics: base.intrinsics, cameraTransform: base.cameraTransform,
            planeTransform: base.planeTransform,
            boundary: [SIMD2(-0.1, -0.1), SIMD2(0.1, -0.1), SIMD2(0.1, 0.1), SIMD2(-0.1, 0.1)],
            imageSize: base.imageSize, orientation: base.orientation)
        var outside = CoorditHostedPoint(landmarkType: "shoulder_left", x: 0.25, y: 0.5, status: "uncertain_proposal")
        let other = CoorditHostedPoint(landmarkType: "shoulder_right", x: 0.75, y: 0.5, status: "visible_proposal")
        XCTAssertFalse(outside.confirm(geometry: narrowPlane))
        XCTAssertEqual(outside.status, "uncertain_proposal")
        XCTAssertNil(CoorditHostedSemantics.segment(CoorditHostedSemantics.pairs(.tshirt)[0],
            points: [outside, other], geometry: narrowPlane, allowUncertainDraft: true))
    }

    func testEveryCategoryKeepsItsMeasurementSchemaAndSkirtHasNoCrotch() {
        for category in CoorditFitLabCategory.allCases {
            XCTAssertEqual(CoorditHostedSemantics.pairs(category).map(\.0), category.cameraDimensions)
        }
        XCTAssertFalse(CoorditHostedSemantics.pairs(.skirt).flatMap { [$0.1, $0.2] }.contains("crotch"))
    }

    func testAnotherCaptureFrameCannotSupplyLandmarksToThisGeometry() {
        let requested = UUID()
        func response(_ frame: UUID) -> CoorditHostedReply {
            let points = CoorditHostedSemantics.pairs(.tshirt).flatMap { [$0.1, $0.2] }.map {
                CoorditHostedPoint(landmarkType: $0, x: 0.4, y: 0.6, status: "visible_proposal")
            }
            return CoorditHostedReply(frameId: frame, lengthBasis: "high_shoulder_to_hem", category: "tshirt", model: "openai/gpt-6-astra",
                provider: "Azure", imageSha256: "hash", coordinateSystem: "upright_rgb_normalized_top_left",
                points: .init(points: points, note: ""), elapsedSeconds: 1, costUsd: 0.01, deploymentApproved: false)
        }
        XCTAssertNoThrow(try response(requested).validate(frameID: requested, category: .tshirt))
        XCTAssertThrowsError(try response(requested).validate(frameID: requested, category: .tshirt, expectedLengthBasis: "back_neck_to_hem"))
        XCTAssertThrowsError(try response(UUID()).validate(frameID: requested, category: .tshirt))
    }
}
