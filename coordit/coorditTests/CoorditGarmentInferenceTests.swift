import XCTest
@testable import coordit

final class CoorditGarmentInferenceTests: XCTestCase {
    func testUnapprovedModelCannotReplaceHeuristicEndpoints() {
        let response = CoorditLandmarkResponse(schemaVersion: 1, status: "needs_calibration", modelVersion: "smoke-v1",
            coordinateSystem: "upright_rgb_normalized_top_left", category: "skirt", deploymentApproved: false, landmarks: [])
        XCTAssertThrowsError(try response.endpoints(for: .skirt))
    }

    func testSkirtContractUsesOnlyWaistHipAndHem() throws {
        let names = ["waist_left", "waist_right", "hip_left", "hip_right", "waist_center", "skirt_hem"]
        let points = names.map { CoorditGarmentLandmark(x: 0.4, y: 0.6, landmarkType: $0,
            visibility: 2, confidence: 0.8, source: "contract_test", correctionStatus: "original") }
        let response = CoorditLandmarkResponse(schemaVersion: 1, status: "needs_calibration", modelVersion: "contract-test",
            coordinateSystem: "upright_rgb_normalized_top_left", category: "skirt", deploymentApproved: true, landmarks: points)
        XCTAssertEqual(try response.endpoints(for: .skirt).count, 6)
        XCTAssertThrowsError(try response.endpoints(for: .pants))
    }

    func testDuplicateMissingAndInvisibleLandmarksAreRejected() {
        let point = CoorditGarmentLandmark(x: 0.4, y: 0.6, landmarkType: "waist_left", visibility: 0,
            confidence: 0.9, source: "contract_test", correctionStatus: "original")
        let response = CoorditLandmarkResponse(schemaVersion: 1, status: "needs_calibration", modelVersion: "contract-test",
            coordinateSystem: "upright_rgb_normalized_top_left", category: "skirt", deploymentApproved: true, landmarks: [point, point])
        XCTAssertThrowsError(try response.endpoints(for: .skirt))
    }

    func testPhotoUploadRequiresHTTPSAndExplicitProcessingConsent() async {
        let provider = CoorditRemoteLandmarkProvider(endpoint: URL(string: "http://example.invalid/v1/landmarks")!,
            bearerToken: "", processingConsent: false)
        do {
            _ = try await provider.infer(Data())
            XCTFail("No consent/HTTP must fail before networking")
        } catch { XCTAssertEqual(error as? CoorditGarmentMeasurementError, .invalidPoint) }
    }
}
