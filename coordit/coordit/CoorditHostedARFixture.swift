#if os(iOS) && DEBUG && targetEnvironment(simulator)
import SwiftUI
import simd

enum CoorditHostedARFixture {
    static var enabled: Bool { ProcessInfo.processInfo.arguments.contains("--coordit-hosted-ar-fixture") }

    @MainActor static var screen: some View {
        let capture = CoorditARPlaneCapture.hostedFixture()
        let pairs = CoorditHostedSemantics.pairs(.tshirt)
        let positions: [(Double, Double)] = [(0.3, 0.3), (0.7, 0.3), (0.3, 0.5), (0.7, 0.5),
            (0.4, 0.25), (0.4, 0.85), (0.7, 0.3), (0.85, 0.45)]
        let names = pairs.flatMap { [$0.1, $0.2] }
        let points = zip(names, positions).map { name, position in
            CoorditHostedPoint(landmarkType: name, x: position.0, y: position.1,
                status: name == "shoulder_left" ? "uncertain_proposal" : "visible_proposal")
        }
        let reply = CoorditHostedReply(frameId: capture.evidence.frameID, lengthBasis: "high_shoulder_to_hem", category: "tshirt", model: "synthetic_ui_fixture_not_api",
            provider: nil, imageSha256: "synthetic", coordinateSystem: "upright_rgb_normalized_top_left",
            points: .init(points: points, note: "authored UI fixture"), elapsedSeconds: 0, costUsd: nil, deploymentApproved: false)
        return CoorditHostedARReview(snapshot: capture, category: .tshirt, initialReply: reply)
    }
}

extension CoorditARPlaneCapture {
    @MainActor static func hostedFixture() -> Self {
        var camera = matrix_identity_float4x4
        camera.columns.1 = SIMD4(0, 0, -1, 0); camera.columns.2 = SIMD4(0, 1, 0, 0)
        camera.columns.3 = SIMD4(0, 1, 0, 1)
        let geometry = CoorditARPlaneGeometry(
            intrinsics: simd_float3x3(rows: [SIMD3(1000, 0, 500), SIMD3(0, 1000, 500), SIMD3(0, 0, 1)]),
            cameraTransform: camera, planeTransform: matrix_identity_float4x4,
            boundary: [SIMD2(-1, -1), SIMD2(1, -1), SIMD2(1, 1), SIMD2(-1, 1)],
            imageSize: SIMD2(1000, 1000), orientation: .up)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1000, height: 1000)).image { context in
            UIColor.systemGray5.setFill(); context.fill(CGRect(x: 0, y: 0, width: 1000, height: 1000))
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 300, y: 300, width: 400, height: 550))
            context.fill(CGRect(x: 150, y: 300, width: 700, height: 150))
        }
        let identity = (0..<4).flatMap { c in (0..<4).map { r in matrix_identity_float4x4[c, r] } }
        let evidence = CoorditARMeasurementEvidence(frameID: UUID(), timestamp: 1, planeID: UUID(), trackingQuality: "normal",
            stablePlaneSeconds: 2, cameraMotionBaselineMeters: 0.04, cameraIntrinsics: [1000,0,0,0,1000,0,500,500,1],
            cameraPose: (0..<4).flatMap { c in (0..<4).map { r in camera[c, r] } }, planePose: identity, imageWidth: 1000, imageHeight: 1000, orientation: "up", corrected: false)
        return .init(hostedFixtureGeometry: geometry, evidence: evidence, image: image)
    }
}
#endif
