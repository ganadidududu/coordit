import XCTest
@testable import coordit

@MainActor
final class CoorditCameraAnalysisTests: XCTestCase {
    func testLegacyReportRequestDoesNotEncodeCameraOptions() throws {
        let request = CoorditFitLabReportRequest(idempotencyKey: "legacy-key", selectedSizeLabel: "M", style: "detailed")
        let data = try JSONEncoder().encode(request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: String])
        XCTAssertEqual(object, ["idempotencyKey": "legacy-key", "selectedSizeLabel": "M", "style": "detailed"])
        XCTAssertEqual(try JSONDecoder().decode(CoorditFitLabReportRequest.self, from: data), request)
        let recommendation = CoorditFitLabRecommendationRequest(referenceClothingIDs: ["reference"], externalProductID: "product", idempotencyKey: "key")
        let recommendationObject = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(recommendation)) as? [String: Any])
        XCTAssertNil(recommendationObject["comparisonBundleAnalysisId"])
    }

    func testCameraRegistersAndSelectsReferenceBeforeReport() async throws {
        let api = CoorditFitLabFixtureAPI(fixtureName: "camera-success")
        let coordinator = makeCoordinator(api: api)
        let measurement = try makeMeasurement()
        try await coordinator.analyzeCameraMeasurement(measurement)
        XCTAssertEqual(coordinator.draft.selectedReferenceIDs, ["reference-camera-fixture"])
        XCTAssertEqual(coordinator.cameraMeasurement?.measurementValues["chest_width"], 54)
        XCTAssertNotNil(coordinator.report)
        XCTAssertEqual(api.requestLedger.first, "camera-reference:card")
        XCTAssertEqual(api.requestLedger.filter { $0.hasPrefix("report:") }.count, 1)
    }

    func testReportFailureRetainsMeasurementsAndRetriesWithoutRegisteringAgain() async throws {
        let api = CoorditFitLabFixtureAPI(fixtureName: "submission-report-failure")
        let coordinator = makeCoordinator(api: api)
        let measurement = try makeMeasurement()
        do { try await coordinator.analyzeCameraMeasurement(measurement); XCTFail("First report must fail") }
        catch { XCTAssertNil(coordinator.report) }
        let reportKey = coordinator.checkpoint.reportIdempotencyKey
        try await coordinator.analyzeCameraMeasurement(measurement)
        XCTAssertEqual(api.requestLedger.filter { $0.hasPrefix("camera-reference:") }.count, 1)
        XCTAssertEqual(coordinator.checkpoint.reportIdempotencyKey, reportKey)
        XCTAssertNotNil(coordinator.report)
    }

    func testRemeasurementKeepsProductAndPaidBundleButRecomputesReport() async throws {
        let api = CoorditFitLabFixtureAPI(fixtureName: "camera-success")
        let coordinator = makeCoordinator(api: api)
        try await coordinator.analyzeCameraMeasurement(makeMeasurement())
        let bundle = coordinator.cameraBundleAnalysisID
        let product = coordinator.createdProductID
        try await coordinator.analyzeCameraMeasurement(makeMeasurement(chest: 56))
        XCTAssertEqual(coordinator.cameraBundleAnalysisID, bundle)
        XCTAssertEqual(coordinator.createdProductID, product)
        XCTAssertEqual(api.requestLedger.filter { $0 == "create-product" }.count, 1)
        XCTAssertEqual(api.requestLedger.filter { $0.hasPrefix("report:") }.count, 2)
        XCTAssertEqual(coordinator.cameraMeasurement?.measurementValues["chest_width"], 56)
        XCTAssertEqual(api.recommendationRequests.last?.comparisonBundleAnalysisID, bundle)
    }

    func testRemeasurementAfterReportFailureReusesThePaidAnalysis() async throws {
        let api = CoorditFitLabFixtureAPI(fixtureName: "submission-report-failure")
        let coordinator = makeCoordinator(api: api)
        do { try await coordinator.analyzeCameraMeasurement(makeMeasurement()); XCTFail("First report must fail") }
        catch { XCTAssertNil(coordinator.report) }
        let paidAnalysisID = try XCTUnwrap(coordinator.recommendation?.fitAnalysisResultID)
        try await coordinator.analyzeCameraMeasurement(makeMeasurement(chest: 55))
        XCTAssertEqual(api.recommendationRequests.last?.comparisonBundleAnalysisID, paidAnalysisID)
        XCTAssertNotNil(coordinator.report)
    }

    private func makeCoordinator(api: CoorditFitLabFixtureAPI) -> CoorditFitLabCoordinator {
        let coordinator = CoorditFitLabCoordinator(route: .fitLabInput, configuration: .init(name: "camera-success", userID: "camera-user", historyRootDirectory: nil, resetsHistory: false), api: api)
        return coordinator
    }

    private func makeMeasurement(chest: Double = 54) throws -> CoorditGarmentMeasurement {
        let values: [(CoorditGarmentDimension, Double)] = [(.shoulder, 48), (.chest, chest), (.length, 68), (.sleeve, 22)]
        let segments = Dictionary(uniqueKeysWithValues: values.map { dimension, length in
            (dimension, CoorditMeasurementSegment(start: .init(x: 0, y: 0), end: .init(x: length / 100, y: 0)))
        })
        return try .init(method: .card, segments: segments, lengthBasis: "high_shoulder_to_hem")
    }
}
