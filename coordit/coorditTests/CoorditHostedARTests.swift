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
