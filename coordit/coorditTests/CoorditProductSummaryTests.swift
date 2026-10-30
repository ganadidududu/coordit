import XCTest
@testable import coordit

@MainActor
final class CoorditProductSummaryTests: XCTestCase {
    func testProductFactsRoundTripAndIdentityValidation() throws {
        let url = try XCTUnwrap(URL(string: "https://shop.example/products/linen-shirt"))
        let facts = CoorditProductFacts(productName: "리넨 셔츠", sourceUrl: url, capturedAt: "2026-10-30T03:00:00.000Z", items: [
            .init(kind: "material", value: "리넨 55%, 면 45%"), .init(kind: "future-kind", value: "unknown")
        ])
        var draft = CoorditFitLabDraft(source: .url, productName: "리넨 셔츠", productURL: url, productFacts: facts)
        let restored = try JSONDecoder().decode(CoorditFitLabDraft.self, from: JSONEncoder().encode(draft))
        XCTAssertEqual(restored.productFacts, facts)
        XCTAssertTrue(facts.applies(to: restored))
        XCTAssertNil(facts.summary(for: ["fit", "future-kind"]))
        draft.productName = "다른 상품"
        XCTAssertFalse(facts.applies(to: draft))
        draft.productName = facts.productName
        draft.productURL = URL(string: "https://shop.example/other")
        XCTAssertFalse(facts.applies(to: draft))
        let legacy = try JSONDecoder().decode(CoorditFitLabURLPrefillResponse.self, from: Data(#"{"productName":"옛 상품","productUrl":"https://shop.example/old","category":"shirt","fitType":"regular","parsingStatus":"parsed","sizes":[]}"#.utf8))
        XCTAssertNil(legacy.productFacts)
    }

    func testConciseReportOnlyComparesSharedValidMeasurements() {
        let draft = CoorditFitLabDraft(sizes: [
            .init(label: "M", measurements: [.chestWidth: 56, .totalLength: 70]),
            .init(label: "L", measurements: [.totalLength: 72, .shoulderWidth: .nan])
        ])
        let reading = CoorditFitLabProductReading(draft: draft).conciseSizeSummary
        XCTAssertTrue(reading.contains("가슴 단면 56cm"))
        XCTAssertTrue(reading.contains("총장 +2cm"))
        XCTAssertFalse(reading.contains("가슴 단면 +"))
        XCTAssertFalse(reading.contains("nan"))
    }

    func testSummaryCalculatesRangesFromProductSizesOnly() {
        let draft = CoorditFitLabDraft(sizes: [
            .init(label: "M", measurements: [.chestWidth: 54, .totalLength: 68]),
            .init(label: "L", measurements: [.chestWidth: 58, .totalLength: 71])
        ])

        let summary = CoorditFitLabProductSummary(draft: draft)

        let chest = summary.measurements.first { $0.key == .chestWidth }
        XCTAssertEqual(chest?.minimum, 54)
        XCTAssertEqual(chest?.maximum, 58)
        XCTAssertEqual(chest?.sizeCount, 2)
        XCTAssertTrue(summary.hasMissingMeasurements)
        XCTAssertFalse(summary.measurements.contains { $0.key == .shoulderWidth })
    }

    func testSummaryDoesNotInventMissingOrInvalidMeasurements() {
        let draft = CoorditFitLabDraft(garmentKind: .lower, category: .pants, sizes: [
            .init(label: "M", measurements: [.waistWidth: 39, .hipWidth: .nan, .rise: -1, .chestWidth: 56]),
            .init(label: "L", measurements: [.waistWidth: 41, .hipWidth: .infinity])
        ])

        let summary = CoorditFitLabProductSummary(draft: draft)

        XCTAssertEqual(summary.measurements.map(\.key), [.waistWidth])
        XCTAssertEqual(summary.measurements.first?.minimum, 39)
        XCTAssertEqual(summary.measurements.first?.maximum, 41)
        XCTAssertTrue(summary.hasMissingMeasurements)
    }

    func testCompleteSingleSizeHasEqualBounds() {
        let draft = CoorditFitLabDraft(sizes: [.init(label: "FREE", measurements: [
            .shoulderWidth: 45, .chestWidth: 56, .totalLength: 70, .sleeveLength: 61
        ])])

        let summary = CoorditFitLabProductSummary(draft: draft)

        XCTAssertFalse(summary.hasMissingMeasurements)
        XCTAssertEqual(summary.measurements.count, 4)
        XCTAssertTrue(summary.measurements.allSatisfy { $0.minimum == $0.maximum })
    }

    func testRestartClearsComparisonStepAndReleaseDisablesCamera() {
        let coordinator = CoorditFitLabCoordinator(route: .fitLabInput,
            configuration: .init(name: "url-success", userID: "release-test", historyRootDirectory: nil, resetsHistory: false))
        coordinator.isComparisonRequested = true

        coordinator.discardAndRestart()

        XCTAssertFalse(coordinator.isComparisonRequested)
        XCTAssertFalse(CoorditGarmentCaptureController.featureEnabled)
    }

    func testReadingExplainsMeasuredCircumferenceAndLengthWithoutPersonalRecommendation() {
        let draft = CoorditFitLabDraft(category: .hoodie, sizes: [
            .init(label: "M", measurements: [.chestWidth: 54, .totalLength: 68]),
            .init(label: "L", measurements: [.chestWidth: 56, .totalLength: 70])
        ])

        let reading = CoorditFitLabProductReading(draft: draft)

        XCTAssertTrue(reading.overview.contains("54~56cm"))
        XCTAssertTrue(reading.sizeDifference.contains("둘레로는 약 4cm"))
        XCTAssertTrue(reading.sizeDifference.contains("2cm 더 길어요"))
        XCTAssertTrue(reading.wearingContext.contains("기모나 안감이 두꺼우면"))
    }

    func testReadingRespectsSmallerMeasurementsRegardlessOfSizeLabel() {
        let draft = CoorditFitLabDraft(garmentKind: .lower, category: .jeans, sizes: [
            .init(label: "A", measurements: [.waistWidth: 40, .outseam: 100]),
            .init(label: "B", measurements: [.waistWidth: 38, .outseam: 98])
        ])

        let reading = CoorditFitLabProductReading(draft: draft)

        XCTAssertTrue(reading.sizeDifference.contains("A보다 B의 허리 단면이 2cm 더 좁아요"))
        XCTAssertTrue(reading.sizeDifference.contains("2cm 더 짧아요"))
        XCTAssertTrue(reading.wearingContext.contains("신축성"))
    }

    func testReadingDoesNotInferDifferenceFromMissingMeasurements() {
        let draft = CoorditFitLabDraft(sizes: [
            .init(label: "M", measurements: [.chestWidth: 54]),
            .init(label: "L", measurements: [.totalLength: 70])
        ])

        let reading = CoorditFitLabProductReading(draft: draft)

        XCTAssertTrue(reading.sizeDifference.contains("공통으로 적힌 치수가 부족해"))
        XCTAssertFalse(reading.sizeDifference.contains("크게 느껴질"))
    }

    func testAutomaticLinkImportRetainsThePagesCategory() async throws {
        let api = CoorditFitLabFixtureAPI(fixtureName: "url-success")
        let coordinator = CoorditFitLabCoordinator(route: .fitLabInput,
            configuration: .init(name: "url-success", userID: "release-test", historyRootDirectory: nil, resetsHistory: false), api: api)

        let result = try await coordinator.prefillProduct(from: XCTUnwrap(URL(string: "https://shop.example/shirt")), category: nil)

        XCTAssertEqual(result.category, .shirt)
        XCTAssertEqual(api.requestLedger.count, 1)
    }

    func testHighlightFindsLargestAdjacentWidthStepAcrossAllSizes() {
        let reading = CoorditFitLabProductReading(draft: .init(sizes: [
            .init(label: "S", measurements: [.chestWidth: 50, .totalLength: 64]),
            .init(label: "M", measurements: [.chestWidth: 51, .totalLength: 65]),
            .init(label: "L", measurements: [.chestWidth: 55, .totalLength: 67])
        ]))
        XCTAssertEqual(reading.sizeDifferenceTitle, "M → L 차이")
        XCTAssertTrue(reading.headline.contains("4cm 넓어요"))
        XCTAssertTrue(reading.headlineDetail.contains("M에서 L"))
    }

    func testHighlightExplainsLengthChangeWithoutClaimingMoreRoom() {
        let reading = CoorditFitLabProductReading(draft: .init(sizes: [
            .init(label: "M", measurements: [.chestWidth: 54, .totalLength: 65]),
            .init(label: "L", measurements: [.chestWidth: 54, .totalLength: 68])
        ]))
        XCTAssertTrue(reading.headline.contains("너비는 같아요"))
        XCTAssertTrue(reading.headlineDetail.contains("기장은 달라져도 가슴 쪽 여유는 같아요"))
    }

    func testHighlightHandlesNonMonotonicSizesAndInvalidMeasurements() {
        let reading = CoorditFitLabProductReading(draft: .init(sizes: [
            .init(label: "M", measurements: [.chestWidth: 54, .totalLength: 70]),
            .init(label: "L", measurements: [.chestWidth: 56, .totalLength: 68])
        ]))
        XCTAssertTrue(reading.headlineDetail.contains("너비와 길이가 반대로"))

        let missing = CoorditFitLabProductReading(draft: .init(sizes: [
            .init(label: "M", measurements: [.chestWidth: .nan]),
            .init(label: "L", measurements: [.chestWidth: -2])
        ]))
        XCTAssertFalse(missing.headline.contains("cm"))
        XCTAssertFalse(missing.headline.contains("같아요"))
    }

    func testSkirtSummaryUsesItsLengthWithoutExpectingTrouserRise() {
        let draft = CoorditFitLabDraft(garmentKind: .lower, category: .skirt, sizes: [
            .init(label: "S", measurements: [.waistWidth: 32, .hipWidth: 45, .totalLength: 70]),
            .init(label: "M", measurements: [.waistWidth: 34, .hipWidth: 47, .totalLength: 73])
        ])
        let summary = CoorditFitLabProductSummary(draft: draft)
        XCTAssertFalse(summary.hasMissingMeasurements)
        XCTAssertEqual(summary.measurements.map(\.key), [.waistWidth, .hipWidth, .totalLength])
        XCTAssertTrue(CoorditFitLabProductReading(draft: draft).sizeDifference.contains("3cm 더 길어요"))
    }

}
