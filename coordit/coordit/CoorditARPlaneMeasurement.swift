import Foundation
import simd

// Intrinsics operate on the unmirrored, unrotated sensor image, with origin at top left.
struct CoorditARPlaneGeometry: Sendable {
    enum Orientation: String, Codable, Sendable {
        case up, right, down, left
        func sensorPoint(_ point: CoorditMeasurementPoint) -> CoorditMeasurementPoint {
            switch self {
            case .up: point
            case .right: .init(x: point.y, y: 1 - point.x)
            case .down: .init(x: 1 - point.x, y: 1 - point.y)
            case .left: .init(x: 1 - point.y, y: point.x)
            }
        }
    }
    let intrinsics: simd_float3x3
    let cameraTransform: simd_float4x4
    let planeTransform: simd_float4x4
    let boundary: [SIMD2<Float>]
    let imageSize: SIMD2<Float>
    let orientation: Orientation

    func worldPoint(_ point: CoorditMeasurementPoint) throws -> CoorditMeasurementVector {
        guard point.isNormalized, imageSize.x > 0, imageSize.y > 0,
              intrinsics[0, 0] > 0, intrinsics[1, 1] > 0,
              abs(simd_determinant(planeTransform)) > 0.0001 else {
            throw CoorditGarmentMeasurementError.invalidPoint
        }
        let sensor = orientation.sensorPoint(point)
        let pixel = SIMD3<Float>(Float(sensor.x) * imageSize.x, Float(sensor.y) * imageSize.y, 1)
        let optical = simd_inverse(intrinsics) * pixel
        // ARKit camera looks down -Z, with +Y up, unlike image coordinates.
        let direction = simd_normalize((cameraTransform * SIMD4<Float>(optical.x, -optical.y, -1, 0)).xyz)
        let origin = cameraTransform.columns.3.xyz
        let normal = simd_normalize(planeTransform.columns.1.xyz)
        let incidence = simd_dot(direction, normal)
        guard abs(incidence) >= 0.5 else { throw CoorditGarmentMeasurementError.invalidPoint }
        let distance = simd_dot(planeTransform.columns.3.xyz - origin, normal) / incidence
        guard distance.isFinite, (0.15...3).contains(distance) else { throw CoorditGarmentMeasurementError.invalidPoint }
        let world = origin + direction * distance
        let local = simd_inverse(planeTransform) * SIMD4<Float>(world, 1)
        let pointOnPlane = SIMD2<Float>(local.x, local.z)
        guard boundary.count >= 3, Self.contains(pointOnPlane, polygon: boundary) else {
            throw CoorditGarmentMeasurementError.invalidPoint
        }
        return .init(world)
    }

    func imagePoint(_ world: CoorditMeasurementVector) -> CoorditMeasurementPoint? {
        let local = simd_inverse(cameraTransform) * SIMD4<Float>(world.simd, 1)
        guard local.z < -0.001 else { return nil }
        let pixel = intrinsics * SIMD3<Float>(local.x / -local.z, -local.y / -local.z, 1)
        let x = Double(pixel.x / imageSize.x), y = Double(pixel.y / imageSize.y)
        let result: CoorditMeasurementPoint
        switch orientation {
        case .up: result = .init(x: x, y: y)
        case .right: result = .init(x: 1 - y, y: x)
        case .down: result = .init(x: 1 - x, y: 1 - y)
        case .left: result = .init(x: y, y: 1 - x)
        }
        return result.isNormalized ? result : nil
    }

    private static func contains(_ point: SIMD2<Float>, polygon: [SIMD2<Float>]) -> Bool {
        var inside = false
        for index in polygon.indices {
            let a = polygon[index], b = polygon[(index + 1) % polygon.count]
            if (a.y > point.y) != (b.y > point.y),
               point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x { inside.toggle() }
        }
        return inside
    }
}

private extension SIMD4 where Scalar == Float {
    var xyz: SIMD3<Float> { .init(x, y, z) }
}

struct CoorditARMeasurementEvidence: Codable, Equatable, Sendable {
    let frameID: UUID
    let timestamp: Double
    let planeID: UUID
    let trackingQuality: String
    let stablePlaneSeconds: Double
    let cameraMotionBaselineMeters: Double
    let cameraIntrinsics: [Float]
    let cameraPose: [Float]
    let planePose: [Float]
    let imageWidth: Int
    let imageHeight: Int
    let orientation: String
    var corrected: Bool

    var isValid: Bool {
        timestamp.isFinite && timestamp > 0 && trackingQuality == "normal" &&
        stablePlaneSeconds.isFinite && stablePlaneSeconds >= 1 &&
        cameraMotionBaselineMeters.isFinite && cameraMotionBaselineMeters >= 0.03 &&
        imageWidth > 0 && imageHeight > 0 && ["up", "right", "down", "left"].contains(orientation) &&
        cameraIntrinsics.count == 9 && cameraPose.count == 16 && planePose.count == 16 &&
        (cameraIntrinsics + cameraPose + planePose).allSatisfy(\.isFinite) &&
        cameraIntrinsics[0] > 0 && cameraIntrinsics[4] > 0
    }
}

// Quality gates are rejection heuristics, not a statistical error bound or proof of cm accuracy.
struct CoorditARPlaneStability {
    private var planeID: UUID?
    private var reference: simd_float4x4?
    private var firstTime: Double?
    private var previousTime: Double?
    private var previousCamera: simd_float4x4?
    private var stillSince: Double?
    private(set) var movement: Float = 0
    private(set) var stableSeconds: Double = 0

    mutating func reset() { self = .init() }

    mutating func observe(planeID: UUID, plane: simd_float4x4, camera: simd_float4x4, timestamp: Double) -> Bool {
        if let previousTime, timestamp <= previousTime { return stableSeconds >= 1 && movement >= 0.03 && stillSince.map { timestamp - $0 >= 0.3 } == true }
        if self.planeID != planeID || previousTime.map({ timestamp - $0 > 0.5 }) == true ||
            reference.map({ simd_distance($0.columns.3, plane.columns.3) > 0.01 || simd_dot($0.columns.1, plane.columns.1) < 0.999 }) == true {
            reset()
        }
        self.planeID = planeID
        reference = reference ?? plane
        firstTime = firstTime ?? timestamp
        if let previousCamera, let previousTime {
            let step = simd_distance(previousCamera.columns.3, camera.columns.3)
            movement += step
            let duration = Float(timestamp - previousTime)
            let still = step / max(duration, 0.001) < 0.03 && simd_dot(previousCamera.columns.2, camera.columns.2) > 0.9995
            stillSince = still ? (stillSince ?? timestamp) : nil
        }
        previousCamera = camera
        previousTime = timestamp
        stableSeconds = timestamp - (firstTime ?? timestamp)
        return stableSeconds >= 1 && movement >= 0.03 && stillSince.map { timestamp - $0 >= 0.3 } == true
    }
}

#if os(iOS)
import ARKit
import CoreImage
import ImageIO
import UIKit

struct CoorditARPlaneCapture {
    let geometry: CoorditARPlaneGeometry
    let evidence: CoorditARMeasurementEvidence
    let image: UIImage

    @MainActor
    init(frame: ARFrame, plane: ARPlaneAnchor, orientation: UIInterfaceOrientation, stability: CoorditARPlaneStability) throws {
        let imageOrientation: CGImagePropertyOrientation
        let mapping: CoorditARPlaneGeometry.Orientation
        switch orientation {
        case .portrait: imageOrientation = .right; mapping = .right
        case .portraitUpsideDown: imageOrientation = .left; mapping = .left
        case .landscapeLeft: imageOrientation = .up; mapping = .up
        case .landscapeRight: imageOrientation = .down; mapping = .down
        default: throw CoorditGarmentMeasurementError.invalidPoint
        }
        let buffer = frame.capturedImage
        let rawWidth = CVPixelBufferGetWidth(buffer), rawHeight = CVPixelBufferGetHeight(buffer)
        let source = CIImage(cvPixelBuffer: buffer).oriented(imageOrientation)
        guard let bitmap = CIContext().createCGImage(source, from: source.extent) else { throw CoorditGarmentMeasurementError.invalidPoint }
        image = UIImage(cgImage: bitmap)
        geometry = .init(intrinsics: frame.camera.intrinsics, cameraTransform: frame.camera.transform,
                         planeTransform: plane.transform, boundary: plane.geometry.boundaryVertices.map { .init($0.x, $0.z) },
                         imageSize: .init(Float(rawWidth), Float(rawHeight)), orientation: mapping)
        func values(_ matrix: simd_float4x4) -> [Float] {
            (0..<4).flatMap { c in (0..<4).map { r in matrix[c, r] } }
        }
        evidence = .init(frameID: UUID(), timestamp: frame.timestamp, planeID: plane.identifier, trackingQuality: "normal",
                         stablePlaneSeconds: stability.stableSeconds, cameraMotionBaselineMeters: Double(stability.movement),
                         cameraIntrinsics: (0..<3).flatMap { c in (0..<3).map { r in frame.camera.intrinsics[c, r] } },
                         cameraPose: values(frame.camera.transform), planePose: values(plane.transform), imageWidth: rawWidth,
                         imageHeight: rawHeight, orientation: mapping.rawValue, corrected: false)
    }
}
#endif
