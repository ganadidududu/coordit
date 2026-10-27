import XCTest

final class CoorditFitLabGarmentUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testEveryGarmentCategoryRendersItsDiagram() {
        for category in ["tshirt", "shirt", "sweatshirt", "hoodie", "knit", "jacket", "coat", "pants", "jeans", "shorts", "skirt"] {
            let lower = ["pants", "jeans", "shorts", "skirt"].contains(category)
            let app = launch(category: category, lower: lower)
            let diagram = element(lower ? "fitlab-mannequin-lower" : "fitlab-mannequin-upper", app)
            XCTAssertTrue(diagram.waitForExistence(timeout: 10))
            XCTAssertEqual(diagram.value as? String, category)
            XCTAssertTrue(element(lower ? "fitlab-overlay-waist_width" : "fitlab-overlay-shoulder_width", app).exists)
            if category == "skirt" { XCTAssertFalse(element("fitlab-overlay-rise", app).exists) }
            capture("garment-\(category)", app)
            app.terminate()
        }
    }

    func testSizeSelectionUpdatesHeroCalloutsAndReason() {
        let app = launch(category: "jacket")
        XCTAssertTrue(element("fitlab-total-score", app).waitForExistence(timeout: 10))
        XCTAssertEqual(element("fitlab-total-score", app).label, "92.0")
        let original = element("fitlab-overlay-chest_width", app).label
        scrollTo("fitlab-size-score-L", app).tap()
        XCTAssertEqual(element("fitlab-recommended-size", app).label, "L")
        XCTAssertEqual(element("fitlab-total-score", app).label, "81.0")
        XCTAssertNotEqual(element("fitlab-overlay-chest_width", app).label, original)
        XCTAssertTrue(element("fitlab-overlay-chest_width", app).label.contains("+2 cm"))
        XCTAssertTrue(app.staticTexts["ABOUT L"].exists)
        capture("jacket-selected-L", app)
        scrollTo("fitlab-size-score-M", app).tap()
        XCTAssertEqual(element("fitlab-total-score", app).label, "92.0")
        XCTAssertEqual(element("fitlab-overlay-chest_width", app).label, original)
        _ = scrollTo("fitlab-size-reason", app)
        capture("jacket-why-M", app)
    }

    func testBackNavigationRetainsCategoryAndSizeComparison() {
        for category in ["jacket", "skirt"] {
            let lower = category == "skirt"
            let app = launch(category: category, lower: lower)
            let diagramID = lower ? "fitlab-mannequin-lower" : "fitlab-mannequin-upper"
            XCTAssertTrue(element(diagramID, app).waitForExistence(timeout: 10))
            XCTAssertEqual(element(diagramID, app).value as? String, category)
            app.buttons["FIT LAB 뒤로가기"].tap()
            scrollTo("fitlab-source-manual", app).tap()
            scrollTo("fitlab-manual-continue", app).tap()
            scrollTo("fitlab-manual-confirm", app).tap()
            XCTAssertTrue(element("fitlab-submission-result", app).waitForExistence(timeout: 10))
            let diagram = scrollTo(diagramID, app)
            XCTAssertEqual(diagram.value as? String, category)
            if lower { XCTAssertFalse(element("fitlab-overlay-rise", app).exists) }
            scrollTo("fitlab-size-score-L", app).tap()
            XCTAssertEqual(element("fitlab-recommended-size", app).label, "L")
            XCTAssertTrue(scrollTo("fitlab-size-reason", app).isHittable)
            XCTAssertTrue(app.staticTexts["ABOUT L"].exists)
            capture("\(category)-retained-result-after-back", app)
            app.terminate()
        }
    }

    func testSavedReportRetainsCategoryAndAlternativeMeasurements() {
        let namespace = UUID().uuidString
        let args = ["--coordit-fitlab-history-namespace", namespace, "--coordit-fitlab-history-user", "garment-user"]
        var app = launch(category: "coat", extra: args)
        XCTAssertTrue(element("fitlab-total-score", app).waitForExistence(timeout: 10))
        scrollTo("fitlab-add-history", app).tap()
        XCTAssertTrue(scrollTo("fitlab-history-card-analysis-fixture-upper", app).isHittable)
        app.terminate()
        app = launch(category: "coat", route: "fitlab-history-detail", extra: args)
        let diagram = element("fitlab-mannequin-upper", app)
        XCTAssertTrue(diagram.waitForExistence(timeout: 10))
        XCTAssertEqual(diagram.value as? String, "coat")
        scrollTo("fitlab-size-score-L", app).tap()
        XCTAssertEqual(element("fitlab-total-score", app).label, "81.0")
        XCTAssertTrue(element("fitlab-overlay-chest_width", app).label.contains("+2 cm"))
        capture("coat-saved-history-selected-L", app)
    }

    func testMissingMeasurementsAndAccessibilityTextRemainReadable() {
        let app = launch(category: "shirt", fixture: "long-report", extra: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge",
            "--coordit-fitlab-accessibility-xxxl"
        ])
        let missing = scrollTo("fitlab-overlay-sleeve_length", app)
        XCTAssertTrue(missing.label.contains("비교 데이터 없음"), missing.label)
        XCTAssertTrue(missing.isHittable)
        XCTAssertGreaterThan(missing.frame.height, 60, "The callout must actually render at accessibility XXXL.")
        for _ in 0..<4 where missing.frame.maxY > app.windows.firstMatch.frame.maxY - 150 {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.42)))
        }
        XCTAssertLessThan(missing.frame.maxY, app.windows.firstMatch.frame.maxY - 150)
        capture("shirt-accessibility-missing-measurement", app)
        scrollTo("fitlab-size-score-L", app).tap()
        XCTAssertEqual(element("fitlab-recommended-size", app).label, "L")
        XCTAssertEqual(element("fitlab-size-score-L", app).value as? String, "선택됨")
        XCTAssertTrue(app.staticTexts["ABOUT L"].exists)
        XCTAssertTrue(scrollTo("fitlab-size-reason", app).isHittable)
        capture("shirt-accessibility-reason", app)
    }

    func testHistoryMigrationStillDecodesWithoutSizeDrafts() {
        let app = launch(category: "hoodie", fixture: "history-edge", route: "fitlab-input", extra: [
            "--coordit-fitlab-history-namespace", UUID().uuidString
        ])
        let audit = element("fitlab-history-run-store-audit", app)
        XCTAssertTrue(audit.waitForExistence(timeout: 10))
        audit.tap()
        let result = element("fitlab-history-store-audit", app)
        let passed = NSPredicate(format: "label CONTAINS %@", "migration=pass")
        expectation(for: passed, evaluatedWith: result)
        waitForExpectations(timeout: 10)
    }

    private func launch(category: String, lower: Bool = false, fixture: String? = nil, route: String? = nil, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--coordit-ui-testing", "--coordit-ui-testing-authenticated", "--coordit-thread-balance", "36",
            "--coordit-start-route", route ?? (lower ? "fitlab-result-bottom" : "fitlab-result-top"),
            "--coordit-fitlab-fixture", fixture ?? (lower ? "lower-result" : "upper-result"),
            "--coordit-test-garment-category", category
        ] + extra
        app.launch()
        return app
    }

    private func element(_ id: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func scrollTo(_ id: String, _ app: XCUIApplication) -> XCUIElement {
        let target = element(id, app)
        for _ in 0..<24 where !target.exists || !target.isHittable {
            let below = !target.exists || target.frame.midY > app.windows.firstMatch.frame.midY
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: below ? 0.65 : 0.42))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: below ? 0.42 : 0.65))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(target.waitForExistence(timeout: 5), id)
        XCTAssertTrue(target.isHittable, id)
        return target
    }

    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
