#if os(iOS) && DEBUG
import Foundation

enum CoorditHostedModel: String, CaseIterable, Identifiable, Codable {
    case astra, gemini
    var id: String { rawValue }
    var title: String { self == .astra ? "Astra" : "Gemini 3.8" }
}

struct CoorditHostedPoint: Codable, Identifiable {
    let landmarkType: String
    var x: Double?
    var y: Double?
    var status: String
    var id: String { landmarkType }
    var position: CoorditMeasurementPoint? {
        guard let x, let y else { return nil }
        let result = CoorditMeasurementPoint(x: x, y: y)
        return result.isNormalized ? result : nil
    }
    var title: String {
        switch landmarkType {
        case "shoulder_left": "왼쪽 어깨 봉제점"
        case "shoulder_right": "오른쪽 어깨 봉제점"
        case "armpit_left": "왼쪽 겨드랑이"
        case "armpit_right": "오른쪽 겨드랑이"
        case "length_start": "총장 시작점"
        case "hem_center": "총장 밑단 끝점"
        case "sleeve_start": "오른쪽 소매 시작"
        case "sleeve_end": "오른쪽 커프 중심"
        case "waist_left": "왼쪽 허리 끝"
        case "waist_right": "오른쪽 허리 끝"
        case "hip_left": "왼쪽 엉덩이 단면"
        case "hip_right": "오른쪽 엉덩이 단면"
        case "waist_center": "허리 중심"
        case "crotch": "가랑이 봉제점"
        case "side_waist": "왼쪽 옆선 시작"
        case "side_hem": "왼쪽 옆선 밑단"
        case "skirt_hem": "스커트 밑단 중심"
        default: landmarkType
        }
    }
    var usable: Bool { position != nil && ["visible_proposal", "user_corrected"].contains(status) }
}

struct CoorditHostedReply: Codable {
    struct Annotation: Codable { var points: [CoorditHostedPoint]; let note: String }
    let frameId: UUID
    let lengthBasis: String
    let category: String
    let model: String
    let provider: String?
    let imageSha256: String
    let coordinateSystem: String
    var points: Annotation
    let elapsedSeconds: Double
    let costUsd: Double?
    let deploymentApproved: Bool

    func validate(frameID: UUID, category: CoorditFitLabCategory, expectedLengthBasis: String? = nil) throws {
        let names = points.points.map(\.landmarkType)
        guard expectedLengthBasis == nil || lengthBasis == expectedLengthBasis,
              frameId == frameID, self.category == category.rawValue, !deploymentApproved,
              coordinateSystem == "upright_rgb_normalized_top_left", !model.isEmpty,
              Set(names) == Set(CoorditHostedSemantics.pairs(category).flatMap { [$0.1, $0.2] }),
              names.count == Set(names).count else { throw CoorditGarmentMeasurementError.invalidPoint }
        for point in points.points {
            guard ["visible_proposal", "uncertain_proposal", "abstain"].contains(point.status),
                  (point.status == "abstain" ? point.x == nil && point.y == nil : point.position != nil) else {
                throw CoorditGarmentMeasurementError.invalidPoint
            }
        }
    }
}

enum CoorditHostedSemantics {
    static func pairs(_ category: CoorditFitLabCategory) -> [(CoorditGarmentDimension, String, String)] {
        if category == .skirt {
            return [(.waist, "waist_left", "waist_right"), (.hip, "hip_left", "hip_right"),
                    (.length, "waist_center", "skirt_hem")]
        }
        if category.garmentKind == .lower {
            return [(.waist, "waist_left", "waist_right"), (.hip, "hip_left", "hip_right"),
                    (.rise, "waist_center", "crotch"), (.outseam, "side_waist", "side_hem")]
        }
        return [(.shoulder, "shoulder_left", "shoulder_right"), (.chest, "armpit_left", "armpit_right"),
                (.length, "length_start", "hem_center"), (.sleeve, "sleeve_start", "sleeve_end")]
    }

    static func segment(_ pair: (CoorditGarmentDimension, String, String), points: [CoorditHostedPoint],
                        geometry: CoorditARPlaneGeometry) -> CoorditMeasurementSegment? {
        guard let a = points.first(where: { $0.id == pair.1 }), a.usable, let p = a.position,
              let b = points.first(where: { $0.id == pair.2 }), b.usable, let q = b.position,
              let start = try? geometry.worldPoint(p), let end = try? geometry.worldPoint(q) else { return nil }
        let segment = CoorditMeasurementSegment(start: start, end: end)
        return pair.0.validRange.contains(segment.centimeters) ? segment : nil
    }
}

struct CoorditHostedARClient {
    let endpoint: URL
    let token: String
    var session = URLSession(configuration: .ephemeral, delegate: CoorditLandmarkNoRedirect(), delegateQueue: nil)

    static let configured: Self? = {
        guard CoorditARFieldTestMode.enabled,
              let address = Bundle.main.object(forInfoDictionaryKey: "CoorditHostedARBaseURL") as? String,
              let base = URL(string: address), base.scheme == "https",
              let token = Bundle.main.object(forInfoDictionaryKey: "CoorditHostedARGatewayToken") as? String,
              token.count >= 32 else { return nil }
        return .init(endpoint: base.appendingPathComponent("v1/hosted-landmarks"), token: token)
    }()

    func infer(image: Data, frameID: UUID, category: CoorditFitLabCategory, model: CoorditHostedModel, lengthBasis: String = "high_shoulder_to_hem") async throws -> CoorditHostedReply {
        guard endpoint.scheme == "https", token.count >= 32 else { throw CoorditGarmentMeasurementError.invalidPoint }
        struct Body: Encodable {
            let imageBase64: String; let frameId: UUID; let category: String; let model: String; let lengthBasis: String
            let processingConsent = true; let trainingConsent = false
        }
        let pixels = try CoorditRemoteLandmarkProvider.metadataFreeJPEG(image)
        let encoder = JSONEncoder(); encoder.keyEncodingStrategy = .convertToSnakeCase
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"; request.timeoutInterval = 115
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try encoder.encode(Body(imageBase64: pixels.base64EncodedString(), frameId: frameID,
            category: category.rawValue, model: model.rawValue,
            lengthBasis: category.garmentKind == .lower ? "waist_to_hem" : lengthBasis))
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200, data.count < 1_000_000 else {
            throw CoorditGarmentMeasurementError.invalidPoint
        }
        let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase
        let result = try decoder.decode(CoorditHostedReply.self, from: data)
        try result.validate(frameID: frameID, category: category,
            expectedLengthBasis: category.garmentKind == .lower ? "waist_to_hem" : lengthBasis)
        return result
    }
}
#endif
