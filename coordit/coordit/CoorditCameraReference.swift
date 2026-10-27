import Foundation

#if os(iOS)

struct CoorditCameraReference: Codable, Equatable, Sendable {
    let reference: CoorditFitLabReferenceRow
    let clothingSizeID: String
}

struct CoorditCameraWardrobeRequest: Encodable {
    let item: CreateClothingItemRequest
    let size: ClothingSizeRequest
    let idempotencyKey: String
}

extension CoorditClosetDraft {
    mutating func applyCameraMeasurement(_ measurement: CoorditGarmentMeasurement, photo: Data?) {
        method = .photo; name = measurement.garmentName
        exactCategory = measurement.resolvedCategory
        category = measurement.isLower ? .bottom : .top
        let values = measurement.resolvedCategory.cameraDimensions.map {
            measurement.measurementValues[$0.measurementKey].map { String($0) } ?? ""
        }
        measurement1 = values[0]; measurement2 = values[1]; measurement3 = values[2]
        measurement4 = values.count > 3 ? values[3] : ""
        cameraMeasurement = measurement; garmentImageData = photo
    }
}

extension CoorditGarmentMeasurement {
    var clothingSizeRequest: ClothingSizeRequest {
        let values = measurementValues
        var metadata = ["source": method.source, "length_basis": lengthBasis, "sleeve_basis": "shoulder_seam_to_cuff", "measured_at": measuredAt.ISO8601Format()]
        if let evidence = arEvidence {
            metadata["ar_frame_id"] = evidence.frameID.uuidString
            metadata["tracking_quality"] = evidence.trackingQuality
            metadata["ar_plane_stable_seconds"] = String(evidence.stablePlaneSeconds)
            metadata["ar_camera_motion_baseline_meters"] = String(evidence.cameraMotionBaselineMeters)
            metadata["correction_status"] = evidence.corrected ? "user_corrected" : "original"
            metadata["measurement_status"] = "measured"
        }
        return .init(sizeLabel: nil, rawMeasurements: metadata, totalLength: values["total_length"], shoulderWidth: values["shoulder_width"], chestWidth: values["chest_width"], sleeveLength: values["sleeve_length"], waistWidth: values["waist_width"], hipWidth: values["hip_width"], rise: values["rise"], outseam: values["outseam"])
    }
}

extension CoorditFitLabHTTPAPI {
    func saveCameraReference(measurement: CoorditGarmentMeasurement, existing: CoorditCameraReference?) async throws -> CoorditCameraReference {
        let sizeID: String
        let itemID: String
        let name = measurement.garmentName
        let category = measurement.resolvedCategory.rawValue
        if let existing {
            let updated: CoorditClothingSizeResponse = try await send(path: "/clothing-sizes/\(existing.clothingSizeID)", method: "PATCH", body: measurement.clothingSizeRequest)
            sizeID = updated.id
            itemID = existing.reference.clothingItemID
        } else {
            let saved: CoorditClothingItemWithSizeResponse = try await send(path: "/clothing-items/with-size", method: "POST", body: CoorditCameraWardrobeRequest(item: .init(name: name, category: category, fitType: "regular", sizeLabel: nil, rawProductData: ["source": measurement.method.source]), size: measurement.clothingSizeRequest, idempotencyKey: measurement.id.uuidString))
            sizeID = saved.clothingSize.id
            itemID = saved.clothingItem.id
        }
        let reference: CoorditFitLabReferenceRow = try await send(path: "/reference-clothing", method: "POST", body: CreateReferenceClothingRequest(clothingItemId: itemID, nickname: name, category: category, fitType: "regular", preferenceScore: 100, isActive: true, notes: "Camera measurement: \(measurement.method.rawValue)"))
        return .init(reference: reference, clothingSizeID: sizeID)
    }
}

extension CoorditFitLabAPI {
    func saveCameraReference(measurement: CoorditGarmentMeasurement, existing: CoorditCameraReference?) async throws -> CoorditCameraReference {
        throw CoorditFitLabError.transport("카메라 측정 저장을 지원하지 않는 연결이에요.")
    }
}
#endif
