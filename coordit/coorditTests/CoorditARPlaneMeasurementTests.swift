import XCTest
import simd
@testable import coordit

@MainActor
final class CoorditARPlaneMeasurementTests: XCTestCase {
    private func geometry(orientation: CoorditARPlaneGeometry.Orientation = .up) -> CoorditARPlaneGeometry {
        // Camera one meter above floor, optical axis points vertically down.
        var camera = matrix_identity_float4x4
        camera.columns.1 = SIMD4(0, 0, -1, 0)
        camera.columns.2 = SIMD4(0, 1, 0, 0)
        camera.columns.3 = SIMD4(0, 1, 0, 1)
        return .init(intrinsics: simd_float3x3(rows: [SIMD3(1000, 0, 500), SIMD3(0, 1000, 500), SIMD3(0, 0, 1)]),
                     cameraTransform: camera, planeTransform: matrix_identity_float4x4,
                     boundary: [SIMD2(-1, -1), SIMD2(1, -1), SIMD2(1, 1), SIMD2(-1, 1)],
                     imageSize: SIMD2(1000, 1000), orientation: orientation)
    }

    func testNonLiDARPlaneComputesTrueThreeDimensionalCentimeters() throws {
        let capture = geometry()
        let start = try capture.worldPoint(.init(x: 0.25, y: 0.5))
        let end = try capture.worldPoint(.init(x: 0.75, y: 0.5))
        XCTAssertEqual(CoorditMeasurementSegment(start: start, end: end).centimeters, 50, accuracy: 0.001)
        XCTAssertEqual(start.y, 0, accuracy: 0.00001)
    }

    func testEveryOrientationRoundTripsFrozenSensorCoordinates() throws {
        for orientation: CoorditARPlaneGeometry.Orientation in [.up, .right, .down, .left] {
            let capture = geometry(orientation: orientation)
            let point = CoorditMeasurementPoint(x: 0.31, y: 0.67)
            let world = try capture.worldPoint(point)
            let projected = try XCTUnwrap(capture.imagePoint(world))
            XCTAssertEqual(projected.x, point.x, accuracy: 0.00001)
            XCTAssertEqual(projected.y, point.y, accuracy: 0.00001)
        }
    }

    func testMissingPlaneOutOfBoundsAndGrazingRaysAreRejected() {
        let base = geometry()
        let empty = CoorditARPlaneGeometry(intrinsics: base.intrinsics, cameraTransform: base.cameraTransform,
            planeTransform: base.planeTransform, boundary: [], imageSize: base.imageSize, orientation: .up)
        XCTAssertThrowsError(try empty.worldPoint(.init(x: 0.5, y: 0.5)))
        XCTAssertThrowsError(try base.worldPoint(.init(x: .nan, y: 0.5)))
        let grazing = CoorditARPlaneGeometry(intrinsics: base.intrinsics, cameraTransform: matrix_identity_float4x4,
            planeTransform: base.planeTransform, boundary: base.boundary, imageSize: base.imageSize, orientation: .up)
        XCTAssertThrowsError(try grazing.worldPoint(.init(x: 0.5, y: 0.5)))
    }

    func testStabilityRequiresMotionBaselineThenStillnessAndResetsOnTrackingGap() {
        var quality = CoorditARPlaneStability()
        let planeID = UUID()
        var camera = matrix_identity_float4x4
        for index in 0..<20 {
            XCTAssertFalse(quality.observe(planeID: planeID, plane: matrix_identity_float4x4, camera: camera, timestamp: Double(index) * 0.1))
        }
        for index in 20..<30 {
            camera.columns.3.x += 0.004
            _ = quality.observe(planeID: planeID, plane: matrix_identity_float4x4, camera: camera, timestamp: Double(index) * 0.1)
        }
        var ready = false
        for index in 30..<36 { ready = quality.observe(planeID: planeID, plane: matrix_identity_float4x4, camera: camera, timestamp: Double(index) * 0.1) }
        XCTAssertTrue(ready)
        XCTAssertFalse(quality.observe(planeID: planeID, plane: matrix_identity_float4x4, camera: camera, timestamp: 5))
        quality.reset()
        XCTAssertEqual(quality.stableSeconds, 0)
        XCTAssertEqual(quality.movement, 0)
    }

    func testNewModesRemainDisabledAndGalleryKeepsCardFallback() {
        XCTAssertFalse(CoorditGarmentCaptureController.cardlessEnabled)
        let controller = CoorditGarmentCaptureController(method: .card)
        controller.loadTestFixture()
        XCTAssertEqual(controller.method, .card)
        XCTAssertTrue(controller.canFinish)
        XCTAssertEqual(CoorditGarmentMeasurement.Method.lidar.rawValue, "lidar")
        XCTAssertEqual(CoorditGarmentMeasurement.Method.card.rawValue, "card")
        XCTAssertEqual(CoorditFitLabCategory.skirt.cameraDimensions, [.waist, .hip, .length])
    }
}
