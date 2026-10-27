#if os(iOS) && DEBUG
import Foundation
import Combine
import UIKit
import Darwin

enum CoorditARFieldTestMode {
    static var enabled: Bool {
        ProcessInfo.processInfo.arguments.contains("--coordit-ar-field-test") ||
            Bundle.main.object(forInfoDictionaryKey: "CoorditARFieldTestBuild") as? Bool == true
    }
}

struct CoorditFieldMeasurement: Codable {
    let dimension: String
    let predictedCm: Double?
    let start2d: CoorditMeasurementPoint?
    let end2d: CoorditMeasurementPoint?
    let start3d: CoorditMeasurementVector?
    let end3d: CoorditMeasurementVector?
}

struct CoorditFieldTrial: Encodable {
    var garmentID: String
    let attemptID: String
    let category: String
    let method: String
    let stage: String
    let algorithmVersion: String
    let recordedAt: Date
    let frameID: String?
    let arEvidence: CoorditARMeasurementEvidence?
    let lengthBasis: String
    let measurements: [CoorditFieldMeasurement]
    let failureReason: String?
    let platform = "ios"
    let device: String = {
        var hardware = utsname()
        uname(&hardware)
        let model = withUnsafeBytes(of: hardware.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        return model + " / iOS " + UIDevice.current.systemVersion
    }()
    var background = "unrecorded"
    var lighting = "unrecorded"
    var groundTruthCm: [String: Double] = [:]
    var independent = false
    #if targetEnvironment(simulator)
    let synthetic = true
    #else
    let synthetic = false
    #endif
}

struct CoorditFieldExport: Encodable {
    let schemaVersion = 1
    let purpose = "local_ar_accuracy_evaluation_not_training"
    let trials: [CoorditFieldTrial]
}

@MainActor final class CoorditARFieldTestSession: ObservableObject {
    @Published var garmentID = ""
    @Published var background = ""
    @Published var lighting = ""
    @Published var groundTruth: [String: String] = [:]
    @Published var independent = false
    @Published private(set) var trials: [CoorditFieldTrial] = []
    @Published var notice: String?
    private var automatic: CoorditFieldTrial?

    func prepareAutomatic(_ capture: CoorditGarmentCaptureController) {
        guard capture.image != nil, !capture.isDetecting, automatic?.attemptID != capture.identifier.uuidString else { return }
        automatic = snapshot(capture, stage: "automatic")
    }

    func hasAutomatic(_ capture: CoorditGarmentCaptureController) -> Bool {
        trials.contains { $0.attemptID == capture.identifier.uuidString && $0.stage == "automatic" }
    }

    func record(_ capture: CoorditGarmentCaptureController, stage: String) throws {
        let name = garmentID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !background.isEmpty, !lighting.isEmpty else {
            throw CoorditFieldTestError.missingMetadata
        }
        let truth = try Dictionary(uniqueKeysWithValues: capture.dimensions.map { dimension in
            guard let value = Double((groundTruth[dimension.measurementKey] ?? "").replacingOccurrences(of: ",", with: ".")),
                  value.isFinite, dimension.validRange.contains(value) else { throw CoorditFieldTestError.missingTape }
            return (dimension.measurementKey, value)
        })
        guard !trials.contains(where: { $0.attemptID == capture.identifier.uuidString && $0.stage == stage }) else {
            throw CoorditFieldTestError.duplicate
        }
        if stage == "manual" && !hasAutomatic(capture) { throw CoorditFieldTestError.recordAutomaticFirst }
        prepareAutomatic(capture)
        var trial = stage == "automatic" ? (automatic ?? snapshot(capture, stage: stage)) : snapshot(capture, stage: stage)
        guard trial.lengthBasis == capture.lengthBasis else { throw CoorditFieldTestError.changedMetadata }
        if let original = trials.first(where: { $0.attemptID == trial.attemptID }),
           original.garmentID != name || original.groundTruthCm != truth || original.lengthBasis != trial.lengthBasis ||
           original.background != background || original.lighting != lighting || original.independent != independent {
            throw CoorditFieldTestError.changedMetadata
        }
        trial.garmentID = name; trial.groundTruthCm = truth; trial.independent = independent
        trial.background = background; trial.lighting = lighting
        trials.append(trial)
        notice = "\(trials.count)개 결과 기록됨 · 사진과 서버 전송 없음"
    }

    func encoded() throws -> Data {
        guard !trials.isEmpty else { throw CoorditFieldTestError.empty }
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(CoorditFieldExport(trials: trials))
    }

    private func snapshot(_ capture: CoorditGarmentCaptureController, stage: String) -> CoorditFieldTrial {
        let usable = capture.canReview && (stage != "automatic" || (capture.hasAutomaticProposal && capture.measurementEvidence?.corrected != true))
        return .init(garmentID: "", attemptID: capture.identifier.uuidString, category: capture.category.rawValue,
            method: capture.method.rawValue, stage: stage,
            algorithmVersion: stage == "automatic" ? "vision_outline_heuristic_not_trained_seam_model" : "user_reviewed_points",
            recordedAt: Date(), frameID: capture.measurementEvidence?.frameID.uuidString, arEvidence: capture.measurementEvidence,
            lengthBasis: capture.lengthBasis, measurements: capture.dimensions.map { dimension in
                let segment = usable ? capture.segments[dimension] : nil
                return .init(dimension: dimension.measurementKey, predictedCm: segment?.centimeters,
                    start2d: segment.flatMap { capture.project($0.start) }, end2d: segment.flatMap { capture.project($0.end) },
                    start3d: segment?.start, end3d: segment?.end)
            }, failureReason: usable ? nil : (capture.arFailureReason ?? capture.message ?? "no_valid_automatic_or_complete_measurement"))
    }
}

enum CoorditFieldTestError: LocalizedError {
    case missingMetadata, missingTape, duplicate, recordAutomaticFirst, changedMetadata, empty
    var errorDescription: String? {
        switch self {
        case .missingMetadata: "시험 정보에서 의류 ID·배경·조명을 입력해주세요."
        case .missingTape: "같은 측정 기준으로 잰 줄자 정답을 모든 부위에 입력해주세요."
        case .duplicate: "같은 촬영의 이 단계는 이미 기록했어요. 다음 시도는 다시 촬영해주세요."
        case .recordAutomaticFirst: "먼저 자동점 또는 자동 실패를 기록해주세요."
        case .changedMetadata: "같은 촬영의 정답·의류 ID·측정 기준이 달라졌어요. 기존 값으로 맞추거나 새로 촬영해주세요."
        case .empty: "먼저 시험 결과를 기록해주세요."
        }
    }
}
#endif
