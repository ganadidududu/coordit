import XCTest
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import coordit

final class CoorditGarmentInferenceTests: XCTestCase {
    @MainActor
    func testInvalidAutomaticLengthKeepsHandlesForCorrection() async throws {
        let capture = CoorditGarmentCaptureController(method: .card, inferenceEngine: InvalidLengthInference())
        capture.loadTestFixture()
        capture.beginManualGarment()
        capture.detectOutline()
        for _ in 0..<100 {
            if !capture.isDetecting { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(capture.points.count, 8, "A bad automatic length must not erase every editable point")
        XCTAssertFalse(capture.canReview, "Unrealistic cm values must still be refused")
        XCTAssertNotNil(capture.message)
    }

    @MainActor
    func testManualEntryCancelsPendingDetectionAndIgnoresItsResult() async throws {
        let capture = CoorditGarmentCaptureController(method: .card, inferenceEngine: DelayedInference())
        capture.loadTestFixture()
        capture.detectOutline()
        XCTAssertTrue(capture.isDetecting)
        capture.beginManualGarment()
        XCTAssertFalse(capture.isDetecting, "Manual entry must be available without waiting for Vision")
        capture.addImagePoint(.init(x: 0.25, y: 0.25))
        try await Task.sleep(for: .milliseconds(120))
        XCTAssertEqual(capture.points.count, 1)
        XCTAssertEqual(capture.selection, .manual)
    }

    @MainActor
    func testCardlessDetectionDoesNotSearchForCardCorners() async throws {
        let capture = CoorditGarmentCaptureController(method: .card)
        capture.loadTestFixture()
        let data = try XCTUnwrap(capture.image?.pngData())
        let result = try await CoorditGarmentOutlineDetector().detect(data, category: .tshirt,
            useForegroundFallback: false, detectCard: false)
        XCTAssertTrue(result.corners.isEmpty)
        XCTAssertEqual(result.endpoints.count, 8)
    }
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
    func testDevelopmentProposalsRequireExplicitOptIn() throws {
        let names = ["waist_left", "waist_right", "hip_left", "hip_right", "waist_center", "skirt_hem"]
        let points = names.enumerated().map { index, name in CoorditGarmentLandmark(x: Double(index + 1) / 8,
            y: 0.5, landmarkType: name, visibility: 2, confidence: 0.8, source: "development_model", correctionStatus: "original") }
        let response = CoorditLandmarkResponse(schemaVersion: 1, status: "needs_calibration", modelVersion: "spatial-v2",
            coordinateSystem: "upright_rgb_normalized_top_left", category: "skirt", deploymentApproved: false, landmarks: points)
        XCTAssertThrowsError(try response.endpoints(for: .skirt))
        XCTAssertEqual(try response.endpoints(for: .skirt, allowDevelopment: true).count, 6)
    }

    @MainActor
    func testAuthenticatedUploadRemovesPhotoGPSMetadata() async throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 30)).image { context in
            UIColor.red.setFill(); context.fill(CGRect(x: 0, y: 0, width: 20, height: 30))
        }
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try XCTUnwrap(image.cgImage), [kCGImagePropertyGPSDictionary:
            [kCGImagePropertyGPSLatitude: 37.0, kCGImagePropertyGPSLongitude: 127.0]] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LandmarkPrivacyURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let provider = CoorditRemoteLandmarkProvider(endpoint: URL(string: "https://example.invalid/garment-landmarks")!,
            bearerToken: "authenticated-user-session", processingConsent: true, session: session)
        let result = try await provider.infer(data as Data)
        XCTAssertFalse(result.deploymentApproved)
        let request = try XCTUnwrap(LandmarkPrivacyURLProtocol.storage.read())
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer authenticated-user-session")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
        XCTAssertEqual(body["training_consent"] as? Bool, false)
        XCTAssertEqual(body["processing_consent"] as? Bool, true)
        let pixels = try XCTUnwrap(Data(base64Encoded: XCTUnwrap(body["image_base64"] as? String)))
        let source = try XCTUnwrap(CGImageSourceCreateWithData(pixels as CFData, nil))
        let metadata = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any])
        XCTAssertNil(metadata[kCGImagePropertyGPSDictionary as String])
    }

}

private struct InvalidLengthInference: CoorditGarmentInferenceEngine {
    func infer(_ input: CoorditGarmentInferenceInput) async throws -> CoorditGarmentOutlineProposal {
        .init(corners: [], outline: [], endpoints: (0..<8).map {
            .init(x: 0.4 + Double($0) * 0.0001, y: 0.4)
        }, isLower: false)
    }
}

private struct DelayedInference: CoorditGarmentInferenceEngine {
    func infer(_ input: CoorditGarmentInferenceInput) async throws -> CoorditGarmentOutlineProposal {
        try await Task.sleep(for: .milliseconds(80))
        return .init(corners: [], outline: [], endpoints: [], isLower: false)
    }
}

private final class LandmarkPrivacyStorage: @unchecked Sendable {
    private let lock = NSLock()
    private var request: URLRequest?
    func write(_ value: URLRequest) { lock.lock(); defer { lock.unlock() }; request = value }
    func read() -> URLRequest? { lock.lock(); defer { lock.unlock() }; return request }
}

private final class LandmarkPrivacyURLProtocol: URLProtocol, @unchecked Sendable {
    static let storage = LandmarkPrivacyStorage()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var captured = request
        if captured.httpBody == nil, let stream = captured.httpBodyStream {
            stream.open(); defer { stream.close() }
            var bytes = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let length = stream.read(&buffer, maxLength: buffer.count)
                if length <= 0 { break }
                bytes.append(buffer, count: length)
            }
            captured.httpBody = bytes
        }
        Self.storage.write(captured)
        let content = Data(#"{"schema_version":1,"status":"needs_calibration","model_version":"test-v2","coordinate_system":"upright_rgb_normalized_top_left","category":"skirt","deployment_approved":false,"landmarks":[]}"#.utf8)
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: content)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
