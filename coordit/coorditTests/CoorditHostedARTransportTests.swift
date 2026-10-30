import XCTest
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import coordit

@MainActor
final class CoorditHostedARTransportTests: XCTestCase {
    func testFrozenFrameModelAndMetadataFreePixelsSurviveGatewayContract() async throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 120)).image { context in
            UIColor.blue.setFill(); context.fill(CGRect(x: 0, y: 0, width: 100, height: 120))
        }
        let input = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(input, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try XCTUnwrap(image.cgImage), [kCGImagePropertyGPSDictionary:
            [kCGImagePropertyGPSLatitude: 37.0, kCGImagePropertyGPSLongitude: 127.0]] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [HostedARContractProtocol.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        let gateway = CoorditHostedARClient(endpoint: URL(string: "https://example.invalid/v1/hosted-landmarks")!,
            token: String(repeating: "x", count: 40), session: session)
        let frame = UUID()
        let reply = try await gateway.infer(image: input as Data, frameID: frame, category: .tshirt, model: .gemini)
        XCTAssertEqual(reply.frameId, frame)
        XCTAssertEqual(reply.model, "google/gemini-3.8-flash")
        XCTAssertEqual(reply.points.points.count, 8)
        XCTAssertFalse(reply.deploymentApproved)
    }

    func testInsecureEndpointFailsBeforePhotoOrNetworkProcessing() async {
        let gateway = CoorditHostedARClient(endpoint: URL(string: "http://example.invalid")!, token: String(repeating: "x", count: 40))
        do {
            _ = try await gateway.infer(image: Data(), frameID: UUID(), category: .tshirt, model: .astra)
            XCTFail("HTTP must never upload photos")
        } catch { XCTAssertEqual(error as? CoorditGarmentMeasurementError, .invalidPoint) }
    }
}

private final class HostedARContractProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            var bytes = request.httpBody ?? Data()
            if bytes.isEmpty, let stream = request.httpBodyStream {
                stream.open(); defer { stream.close() }
                var buffer = [UInt8](repeating: 0, count: 4096)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    if count <= 0 { break }
                    bytes.append(buffer, count: count)
                }
            }
            let body = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer " + String(repeating: "x", count: 40))
            XCTAssertEqual(body["model"] as? String, "gemini")
            XCTAssertEqual(body["category"] as? String, "tshirt")
            XCTAssertEqual(body["length_basis"] as? String, "high_shoulder_to_hem")
            XCTAssertEqual(body["processing_consent"] as? Bool, true)
            XCTAssertEqual(body["training_consent"] as? Bool, false)
            let pixels = try XCTUnwrap(Data(base64Encoded: XCTUnwrap(body["image_base64"] as? String)))
            let source = try XCTUnwrap(CGImageSourceCreateWithData(pixels as CFData, nil))
            let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any])
            XCTAssertNil(properties[kCGImagePropertyGPSDictionary as String])
            let names = ["shoulder_left", "shoulder_right", "armpit_left", "armpit_right", "length_start", "hem_center", "sleeve_start", "sleeve_end"]
            let responseBody: [String: Any] = ["frame_id": try XCTUnwrap(body["frame_id"]), "category": "tshirt", "length_basis": try XCTUnwrap(body["length_basis"]),
                "model": "google/gemini-3.8-flash", "provider": "contract_fixture", "image_sha256": "fixture",
                "coordinate_system": "upright_rgb_normalized_top_left", "deployment_approved": false,
                "elapsed_seconds": 1, "cost_usd": 0.002,
                "points": ["note": "contract fixture", "points": names.map {
                    ["landmark_type": $0, "x": NSNull(), "y": NSNull(), "status": "abstain"] as [String: Any]
                }]]
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: try JSONSerialization.data(withJSONObject: responseBody))
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
