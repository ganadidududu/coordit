import XCTest

final class CoorditCategorySelectionUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testClosetAndFitLabLinkUseTheSameCategorySheet() {
        for prefix in ["closet", "fitlab-url"] {
            let app = launch(route: prefix == "closet" ? "closet-add-method" : "fitlab-input")
            if prefix == "closet" {
                capture("closet-title-without-fade", app)
                tap("closet-add-method-link", app)
            } else { tap("fitlab-source-url", app) }
            let picker = element("\(prefix)-category-picker", app)
            XCTAssertTrue(picker.waitForExistence(timeout: 5))
            XCTAssertEqual(picker.value as? String, "티셔츠")
            capture("\(prefix)-category-row", app)
            tap("\(prefix)-category-picker", app)
            XCTAssertTrue(element("category-sheet", app).waitForExistence(timeout: 5))
            capture("\(prefix)-upper-sheet", app)
            tap("\(prefix)-category-shirt", app)
            XCTAssertTrue(element("category-sheet", app).waitForNonExistence(timeout: 5))
            XCTAssertEqual(picker.value as? String, "셔츠")
            XCTAssertTrue(app.buttons["하의"].waitForExistence(timeout: 5))
            app.buttons["하의"].tap()
            XCTAssertEqual(picker.value as? String, "팬츠")
            tap("\(prefix)-category-picker", app)
            XCTAssertFalse(element("\(prefix)-category-shirt", app).exists)
            capture("\(prefix)-lower-sheet", app)
            tap("\(prefix)-category-jeans", app)
            XCTAssertTrue(element("category-sheet", app).waitForNonExistence(timeout: 5))
            XCTAssertEqual(picker.value as? String, "데님")
            app.terminate()
        }
    }

    func testManualAndOCRUseTheSameCategorySheet() {
        let manual = launch(route: "fitlab-input")
        tap("fitlab-source-manual", manual)
        tap("fitlab-category-picker", manual)
        capture("manual-category-sheet", manual)
        tap("fitlab-category-shirt", manual)
        XCTAssertTrue(element("category-sheet", manual).waitForNonExistence(timeout: 5))
        XCTAssertEqual(element("fitlab-category-picker", manual).value as? String, "셔츠")
        manual.terminate()

        let ocr = launch(route: "fitlab-input", fixture: "ocr-upper")
        tap("fitlab-source-ocr", ocr)
        tap("fitlab-ocr-simulator-fixture", ocr)
        tap("fitlab-ocr-category-picker", ocr)
        capture("ocr-category-sheet", ocr)
        tap("fitlab-ocr-category-shirt", ocr)
        XCTAssertTrue(element("category-sheet", ocr).waitForNonExistence(timeout: 5))
        XCTAssertEqual(element("fitlab-ocr-category-picker", ocr).value as? String, "셔츠")
    }

    func testExistingReferenceSelectionKeepsBothComparisonOptions() {
        let app = launch(route: "fitlab-input", fixture: "url-success")
        tap("fitlab-source-url", app)
        tap("fitlab-url-field", app)
        element("fitlab-url-field", app).typeText("https://shop.example/products/shirt\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        tap("fitlab-url-import", app)
        tap("fitlab-reference-reference-fixture-tshirt", app)
        XCTAssertTrue(element("fitlab-camera-comparison", app).exists)
        XCTAssertTrue(element("fitlab-choose-closet", app).exists)
        XCTAssertTrue(element("fitlab-submit-analysis", app).isEnabled)
        capture("comparison-with-existing-reference", app)
        tap("fitlab-choose-closet", app)
        XCTAssertFalse(element("fitlab-reference-reference-fixture-tshirt", app).exists)
        tap("fitlab-choose-closet", app)
        XCTAssertEqual(element("fitlab-reference-reference-fixture-tshirt", app).value as? String, "선택됨")
        tap("fitlab-camera-comparison", app)
        XCTAssertTrue(element("camera-fit-screen", app).waitForExistence(timeout: 5))
    }

    func testCategorySheetAtAccessibilityTextSize() {
        let app = launch(route: "closet-add-link", largeText: true)
        tap("closet-category-picker", app)
        capture("category-sheet-accessibility", app)
        tap("closet-category-coat", app)
        XCTAssertTrue(element("category-sheet", app).waitForNonExistence(timeout: 5))
        XCTAssertEqual(element("closet-category-picker", app).value as? String, "코트")
    }

    private func launch(route: String, fixture: String? = nil, largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--coordit-ui-testing", "--coordit-start-route", route, "--coordit-thread-balance", "3"]
        if let fixture { app.launchArguments += ["--coordit-fitlab-fixture", fixture] }
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"] }
        app.launch()
        return app
    }

    private func element(_ id: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func tap(_ id: String, _ app: XCUIApplication) {
        let target = element(id, app)
        XCTAssertTrue(target.waitForExistence(timeout: 10), id)
        for _ in 0..<14 {
            let covered = !element("category-sheet", app).exists && target.frame.maxY > app.frame.maxY - 110
            if target.isHittable && !covered { break }
            if target.frame.midY < app.frame.midY { app.swipeDown() } else { app.swipeUp() }
        }
        XCTAssertTrue(target.isHittable, id)
        target.tap()
    }

    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
