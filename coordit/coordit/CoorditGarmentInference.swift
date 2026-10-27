#if os(iOS)
import Foundation

struct CoorditGarmentInferenceInput: Sendable {
    let image: Data
    let category: CoorditFitLabCategory
    let cardHint: CoorditMeasurementPoint?
    let garmentHint: CoorditMeasurementPoint?
}

protocol CoorditGarmentInferenceEngine: Sendable {
    func infer(_ input: CoorditGarmentInferenceInput) async throws -> CoorditGarmentOutlineProposal
}

struct CoorditGarmentLandmark: Codable, Sendable {
    let x: Double
    let y: Double
    let landmarkType: String
    let visibility: Int
    let confidence: Double
    let source: String
    let correctionStatus: String
}

struct CoorditLandmarkResponse: Decodable, Sendable {
    let schemaVersion: Int
    let status: String
    let modelVersion: String
    let coordinateSystem: String
    let category: String
    let deploymentApproved: Bool
    let landmarks: [CoorditGarmentLandmark]

    func endpoints(for category: CoorditFitLabCategory) throws -> [CoorditMeasurementPoint] {
        guard schemaVersion == 1, !modelVersion.isEmpty, deploymentApproved, self.category == category.rawValue,
              coordinateSystem == "upright_rgb_normalized_top_left", status == "needs_calibration",
              Set(landmarks.map(\.landmarkType)).count == landmarks.count else {
            throw CoorditGarmentMeasurementError.invalidPoint
        }
        let names: [String]
        if category == .skirt {
            names = ["waist_left", "waist_right", "hip_left", "hip_right", "waist_center", "skirt_hem"]
        } else if category.garmentKind == .lower {
            names = ["waist_left", "waist_right", "hip_left", "hip_right", "waist_center", "crotch", "side_waist", "side_hem"]
        } else {
            names = ["shoulder_left", "shoulder_right", "armpit_left", "armpit_right", "length_start", "hem_center", "sleeve_start", "sleeve_end"]
        }
        return try names.map { name in
            guard let landmark = landmarks.first(where: { $0.landmarkType == name }), landmark.visibility == 2,
                  landmark.confidence.isFinite, (0.7...1).contains(landmark.confidence),
                  CoorditMeasurementPoint(x: landmark.x, y: landmark.y).isNormalized else {
                throw CoorditGarmentMeasurementError.invalidPoint
            }
            return .init(x: landmark.x, y: landmark.y)
        }
    }
}

struct CoorditRemoteLandmarkProvider: Sendable {
    let endpoint: URL
    // Supplied by an authenticated gateway, never embedded as a shared app API key.
    let bearerToken: String
    let processingConsent: Bool

    func infer(_ image: Data) async throws -> CoorditLandmarkResponse {
        guard processingConsent, endpoint.scheme == "https", image.count <= 3_000_000 else {
            throw CoorditGarmentMeasurementError.invalidPoint
        }
        struct Body: Encodable {
            let image_base64: String
            let processing_consent = true
            let training_consent = false
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(Body(image_base64: image.base64EncodedString()))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200, data.count <= 1_000_000 else {
            throw CoorditGarmentMeasurementError.invalidPoint
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(CoorditLandmarkResponse.self, from: data)
    }
}

struct CoorditHybridGarmentInference: CoorditGarmentInferenceEngine {
    var remote: CoorditRemoteLandmarkProvider?

    func infer(_ input: CoorditGarmentInferenceInput) async throws -> CoorditGarmentOutlineProposal {
        let local = try await CoorditGarmentOutlineDetector().detect(input.image, category: input.category,
            cardHint: input.cardHint, garmentHint: input.garmentHint)
        guard let remote,
              Bundle.main.object(forInfoDictionaryKey: "CoorditAILandmarksEnabled") as? Bool == true,
              input.cardHint == nil, input.garmentHint == nil else { return local }
        do {
            let result = try await remote.infer(input.image)
            let endpoints = try result.endpoints(for: input.category)
            try Task.checkCancellation()
            return .init(corners: local.corners, outline: local.outline, endpoints: endpoints,
                isLower: input.category.garmentKind == .lower, usedForegroundMask: local.usedForegroundMask)
        } catch is CancellationError { throw CancellationError() }
        catch { return local }
    }
}
#endif
