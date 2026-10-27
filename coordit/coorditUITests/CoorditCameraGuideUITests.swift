import XCTest

final class CoorditCameraGuideUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testExistingCategoriesAutomaticPhotoAndClosetSaveWithoutFixedGuide() {
        for (category, title) in [("hoodie", "후드"), ("shorts", "쇼츠"), ("skirt", "스커트")] {
            let app = XCUIApplication()
            app.launchArguments = ["--coordit-ui-testing", "--coordit-start-route", "closet-add-method", "--coordit-test-closet-save-success"]
            app.launch()
            element("closet-add-method-photo", app).tap()
            if category != "hoodie" { element("closet-camera-kind-lower", app).tap() }
            element("closet-camera-category-picker", app).tap()
            element("closet-camera-category-\(category)", app).tap()
            element("closet-camera-continue", app).tap()
            XCTAssertTrue(element("camera-fit-take-photo", app).waitForExistence(timeout: 5))
            XCTAssertFalse(element("camera-fit-guide-\(category)", app).exists)
            capture("\(category)-capture-entry", app)
            element("camera-fit-take-photo", app).tap()
            XCTAssertTrue(element("camera-fit-shutter", app).waitForExistence(timeout: 5))
            XCTAssertTrue(element("camera-fit-motion-hint", app).exists)
            capture("\(category)-camera-motion", app)
            element("camera-fit-shutter", app).tap()
            XCTAssertTrue(element("camera-fit-point-0", app).waitForExistence(timeout: 15))
            XCTAssertTrue(element("camera-fit-analyze", app).isEnabled)
            element("camera-fit-select-card", app).tap()
            XCTAssertTrue(element("camera-fit-card-corner-0", app).exists)
            capture("\(category)-automatic-photo", app)
            if category == "skirt" { XCTAssertFalse(element("camera-fit-measurement-rise", app).exists) }
            element("camera-fit-analyze", app).tap()
            XCTAssertTrue(element("closet-detail-garment-photo", app).waitForExistence(timeout: 10))
            XCTAssertEqual(element("closet-detail-garment-photo", app).value as? String, "selected")
            XCTAssertTrue(app.staticTexts["잘 맞는 \(title)"].exists)
            capture("\(category)-saved", app)
            app.terminate()
        }
    }

    func testMotionHintAndCancelAtLargeTextSize() {
        let app = XCUIApplication()
        app.launchArguments = ["--coordit-ui-testing", "--coordit-start-route", "closet-add-method", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"]
        app.launch()
        element("closet-add-method-photo", app).tap()
        element("closet-camera-continue", app).tap()
        XCTAssertFalse(element("camera-fit-sleeve-guide", app).exists)
        element("camera-fit-take-photo", app).tap()
        XCTAssertTrue(element("camera-fit-shutter", app).waitForExistence(timeout: 5))
        XCTAssertTrue(element("camera-fit-motion-hint", app).exists)
        capture("motion-large-camera", app)
        app.buttons["촬영 닫기"].tap()
        XCTAssertTrue(element("camera-fit-select-photo", app).waitForExistence(timeout: 5))
        XCTAssertFalse(element("camera-fit-analyze", app).isEnabled)
    }

    func testTapCardRecoveryAndDragCorrection() {
        let app = XCUIApplication()
        app.launchArguments = ["--coordit-ui-testing", "--coordit-start-route", "closet-add-method", "--coordit-test-closet-save-success", "--coordit-test-ambiguous-card"]
        app.launch()
        element("closet-add-method-photo", app).tap()
        element("closet-camera-continue", app).tap()
        element("camera-fit-take-photo", app).tap()
        element("camera-fit-shutter", app).tap()
        XCTAssertTrue(element("camera-fit-photo-viewport", app).waitForExistence(timeout: 10))
        let instruction = element("camera-fit-instruction", app)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", "카드를 눌러"), object: instruction)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
        XCTAssertFalse(element("camera-fit-analyze", app).isEnabled)
        app.swipeUp()
        let photo = element("camera-fit-photo-viewport", app)
        photo.coordinate(withNormalizedOffset: CGVector(dx: 300.0 / 2400, dy: 2725.0 / 3000)).tap()
        XCTAssertTrue(element("camera-fit-point-0", app).waitForExistence(timeout: 15))
        XCTAssertTrue(element("camera-fit-analyze", app).isEnabled)
        let corner = element("camera-fit-card-corner-0", app)
        XCTAssertTrue(corner.exists)
        let origin = corner.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        origin.press(forDuration: 0.1, thenDragTo: origin.withOffset(CGVector(dx: -1, dy: 0)))
        capture("tap-card-recovery", app)
        element("camera-fit-analyze", app).tap()
        XCTAssertTrue(element("closet-detail-garment-photo", app).waitForExistence(timeout: 10))
    }

    private func element(_ id: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
