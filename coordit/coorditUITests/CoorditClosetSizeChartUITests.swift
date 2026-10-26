import XCTest

final class CoorditClosetSizeChartUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testSizeChartEntryKeepsCameraAndLinkSeparate() {
        let app = launch()
        XCTAssertTrue(element("closet-add-method-photo", app).exists)
        XCTAssertTrue(element("closet-add-method-link", app).exists)
        capture("closet-three-registration-methods", app)
        tap("closet-add-method-sizeChart", app)
        XCTAssertTrue(element("closet-size-chart-photo", app).waitForExistence(timeout: 5))
        XCTAssertTrue(element("closet-size-chart-camera", app).exists)
        XCTAssertFalse(element("closet-add-submit", app).isEnabled)
        capture("closet-size-chart-empty", app)
        tap("closet-size-chart-photo", app)
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5) || app.buttons["취소"].exists)
        capture("closet-size-chart-photo-library", app)
    }

    func testCapturedChartRecognizesSelectedSizeAndSavesMeasurements() {
        let app = launch(arguments: ["--coordit-test-ocr-crop-and-rows", "--coordit-test-closet-save-success"])
        tap("closet-add-method-sizeChart", app)
        XCTAssertTrue(element("size-chart-cropper", app).waitForExistence(timeout: 5))
        capture("closet-size-chart-crop", app)
        app.buttons["표 영역 사용"].tap()
        XCTAssertTrue(element("closet-ocr-size-row-W32", app).waitForExistence(timeout: 20))
        XCTAssertFalse(element("closet-add-submit", app).isEnabled)
        tap("closet-ocr-size-row-FREE", app)
        XCTAssertEqual(element("closet-selected-size-label", app).label, "FREE")
        tap("closet-ocr-size-row-W32", app)
        XCTAssertTrue(element("closet-add-submit", app).isEnabled)
        capture("closet-size-chart-selected", app)
        tap("closet-add-submit", app)
        XCTAssertTrue(element("coordit-screen-closet-add-result", app).waitForExistence(timeout: 10))
        let label = element("closet-detail-size-label", app)
        for _ in 0..<5 where !label.isHittable { app.swipeUp() }
        XCTAssertEqual(label.label, "W32")
        XCTAssertTrue(element("closet-detail-measurement-waist-width", app).label.contains("41"))
        XCTAssertTrue(element("closet-detail-measurement-outseam", app).label.contains("103"))
        capture("closet-size-chart-saved", app)
    }

    private func launch(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--coordit-ui-testing", "--coordit-start-route", "closet-add-method"] + arguments
        app.launch()
        return app
    }

    private func element(_ id: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func tap(_ id: String, _ app: XCUIApplication) {
        let target = element(id, app)
        XCTAssertTrue(target.waitForExistence(timeout: 10), id)
        for _ in 0..<10 {
            if target.isHittable && target.frame.maxY < app.frame.maxY - 110 { break }
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
