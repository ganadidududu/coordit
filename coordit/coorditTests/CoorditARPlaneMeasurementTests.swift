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
    func testMillimeterJitterCannotFakeThreeCentimeterMotionBaseline() {
        var quality = CoorditARPlaneStability()
        let planeID = UUID()
        var camera = matrix_identity_float4x4
        var ready = false
        for index in 0..<100 {
            camera.columns.3.x = index.isMultiple(of: 2) ? 0 : 0.001
            ready = quality.observe(planeID: planeID, plane: matrix_identity_float4x4, camera: camera, timestamp: Double(index) * 0.1)
        }
        XCTAssertFalse(ready, "Millimeter jitter must not establish metric-scale motion baseline")
        XCTAssertLessThan(quality.movement, 0.003)
    }

    func testContinuingCameraRollCannotPassAsStillness() {
        var quality = CoorditARPlaneStability()
        let planeID = UUID()
        var camera = matrix_identity_float4x4
        for index in 0..<10 {
            camera.columns.3.x = Float(index) * 0.005
            _ = quality.observe(planeID: planeID, plane: matrix_identity_float4x4, camera: camera, timestamp: Double(index) * 0.1)
        }
        var ready = false
        for index in 10..<30 {
            camera = simd_float4x4(simd_quatf(angle: Float(index - 10) * 0.01, axis: SIMD3(0, 0, 1)))
            camera.columns.3.x = 0.045
            ready = quality.observe(planeID: planeID, plane: matrix_identity_float4x4, camera: camera, timestamp: Double(index) * 0.1)
        }
        XCTAssertFalse(ready, "Roll at 0.1 radians/sec must fail shutter stillness")
    }

    func testBackwardFrameCannotReuseAReadyCapture() {
        var quality = CoorditARPlaneStability()
        let planeID = UUID()
        var camera = matrix_identity_float4x4
        for index in 0..<30 {
            camera.columns.3.x = min(0.04, Float(index) * 0.004)
            _ = quality.observe(planeID: planeID, plane: matrix_identity_float4x4, camera: camera, timestamp: Double(index) * 0.1)
        }
        XCTAssertFalse(quality.observe(planeID: planeID, plane: matrix_identity_float4x4, camera: camera, timestamp: 2.89))
        XCTAssertEqual(quality.stableSeconds, 0)
    }

    func testKnownGarmentCentimetersAcrossCameraHeightTiltAndOrientation() throws {
        let segments: [(SIMD3<Float>, SIMD3<Float>)] = [
            (SIMD3(-0.3, 0, 0), SIMD3(0.3, 0, 0)),
            (SIMD3(-0.21, 0, -0.25), SIMD3(0.21, 0, -0.25)),
            (SIMD3(0, 0, -0.4), SIMD3(0, 0, 0.4)),
            (SIMD3(0.2, 0, -0.3), SIMD3(0.45, 0, -0.05)),
            (SIMD3(-0.35, 0, 0.1), SIMD3(0.35, 0, 0.1))
        ]
        var checked = 0
        var rows = ["height_m,tilt_radians,orientation,expected_cm,computed_cm,error_cm"]
        for height: Float in [0.65, 1.1, 1.8] {
            for tilt: Float in [0, 0.25, 0.5] {
                let forward = SIMD3<Float>(0, -cos(tilt), -sin(tilt))
                let right = SIMD3<Float>(1, 0, 0)
                let up = SIMD3<Float>(0, sin(tilt), -cos(tilt))
                let origin = SIMD3<Float>(0, height, height * tan(tilt))
                let camera = simd_float4x4(columns: (SIMD4(right, 0), SIMD4(up, 0), SIMD4(-forward, 0), SIMD4(origin, 1)))
                for orientation: CoorditARPlaneGeometry.Orientation in [.up, .right, .down, .left] {
                    let capture = CoorditARPlaneGeometry(intrinsics: simd_float3x3(rows: [
                        SIMD3(1200, 0, 946), SIMD3(0, 1180, 716), SIMD3(0, 0, 1)]),
                        cameraTransform: camera, planeTransform: matrix_identity_float4x4,
                        boundary: [SIMD2(-1, -1), SIMD2(1, -1), SIMD2(1, 1), SIMD2(-1, 1)],
                        imageSize: SIMD2(1920, 1440), orientation: orientation)
                    // Independent forward camera projection from known physical points.
                    func pixel(_ point: SIMD3<Float>) -> CoorditMeasurementPoint {
                        let delta = point - origin
                        let depth = simd_dot(delta, forward)
                        let x = Double((946 + 1200 * simd_dot(delta, right) / depth) / 1920)
                        let y = Double((716 - 1180 * simd_dot(delta, up) / depth) / 1440)
                        switch orientation {
                        case .up: return .init(x: x, y: y)
                        case .right: return .init(x: 1-y, y: x)
                        case .down: return .init(x: 1-x, y: 1-y)
                        case .left: return .init(x: y, y: 1-x)
                        }
                    }
                    for (a, b) in segments {
                        let pa = pixel(a), pb = pixel(b)
                        guard pa.isNormalized, pb.isNormalized else { continue }
                        let result = CoorditMeasurementSegment(start: try capture.worldPoint(pa), end: try capture.worldPoint(pb))
                        let expected = Double(simd_distance(a, b)) * 100
                        XCTAssertEqual(result.centimeters, expected, accuracy: 0.003)
                        rows.append("\(height),\(tilt),\(orientation.rawValue),\(expected),\(result.centimeters),\(result.centimeters - expected)")
                        checked += 1
                    }
                }
            }
        }
        XCTAssertGreaterThanOrEqual(checked, 160)
        let attachment = XCTAttachment(string: rows.joined(separator: "\n"))
        attachment.name = "ar-mathematical-lengths-not-real-sensor-accuracy.csv"
        attachment.lifetime = .keepAlways; add(attachment)
    }

}
