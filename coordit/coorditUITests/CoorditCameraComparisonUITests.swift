import XCTest

final class CoorditCameraComparisonUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testLinkToAutomaticCardMeasurementAndReportWithoutTableConfirmation() {
        let app = XCUIApplication()
        app.launchArguments = ["--coordit-ui-testing", "--coordit-start-route", "fitlab-input", "--coordit-fitlab-fixture", "camera-demo", "--coordit-thread-balance", "3"]
        app.launch()
        XCTAssertTrue(element("fitlab-source-url", app).waitForExistence(timeout: 5))
        XCTAssertFalse(element("fitlab-reference-prerequisite", app).exists)
        capture("simple-entry", app)
        element("fitlab-source-url", app).tap()
        let field = element("fitlab-url-field", app)
        field.tap()
        field.typeText("https://shop.example/products/cotton-crewneck\n")
        capture("simple-link", app)
        reachable("fitlab-url-import", app).tap()
        XCTAssertTrue(element("fitlab-camera-comparison", app).waitForExistence(timeout: 5))
        XCTAssertFalse(element("fitlab-url-review", app).exists)
        XCTAssertFalse(element("fitlab-url-confirmed", app).exists)
        capture("simple-reference", app)
        reachable("fitlab-camera-comparison", app).tap()
        capture("simple-camera-empty", app)
        reachable("camera-fit-test-auto", app).tap()
        XCTAssertTrue(element("camera-fit-point-0", app).waitForExistence(timeout: 15))
        XCTAssertTrue(element("camera-fit-analyze", app).isEnabled)
        XCTAssertFalse(element("camera-fit-unlocked", app).exists)
        for _ in 0..<3 { app.swipeDown() }
        capture("simple-auto-points", app)
        let point = element("camera-fit-point-0", app)
        let origin = point.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        origin.press(forDuration: 0.1, thenDragTo: origin.withOffset(CGVector(dx: 8, dy: 0)))
        XCTAssertTrue(element("camera-fit-analyze", app).isEnabled)
        capture("simple-confirm", app)
        element("camera-fit-analyze", app).tap()
        XCTAssertTrue(element("camera-fit-unlocked", app).waitForExistence(timeout: 8))
        reachable("camera-fit-size-L", app).tap()
        capture("simple-comparison", app)
        element("camera-fit-analyze", app).tap()
        XCTAssertTrue(element("coordit-screen-fitlab-result-top", app).waitForExistence(timeout: 5))
        XCTAssertEqual(element("coordit-thread-balance-probe", app).label, "2")
        capture("simple-report", app)
    }

    func testClosetPrioritizesCameraAndLinkWithManualFallback() {
        let app = XCUIApplication()
        app.launchArguments = ["--coordit-ui-testing", "--coordit-start-route", "closet-add-method"]
        app.launch()
        XCTAssertTrue(element("closet-add-method-photo", app).waitForExistence(timeout: 5))
        XCTAssertTrue(element("closet-add-method-link", app).exists)
        XCTAssertTrue(element("closet-add-method-manual", app).exists)
        XCTAssertLessThan(element("closet-add-method-manual", app).frame.width, element("closet-add-method-link", app).frame.width / 2)
        capture("simple-closet-methods", app)
        element("closet-add-method-photo", app).tap()
        XCTAssertTrue(app.buttons["바지"].waitForExistence(timeout: 3))
        capture("simple-closet-category", app)
        app.buttons["바지"].tap()
        XCTAssertTrue(element("camera-fit-screen", app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["바지를 평평하게 펴주세요."].exists)
        capture("simple-pants-camera", app)
    }

    func testClosetCaptureAutomaticallyFillsGarmentPhoto() {
        let app = XCUIApplication()
        app.launchArguments = ["--coordit-ui-testing", "--coordit-start-route", "closet-add-method", "--coordit-test-closet-save-success"]
        app.launch()
        element("closet-add-method-photo", app).tap()
        app.buttons["반팔 티셔츠"].tap()
        reachable("camera-fit-test-fixture", app).tap()
        reachable("camera-fit-analyze", app).tap()
        let photo = element("closet-detail-garment-photo", app)
        XCTAssertTrue(photo.waitForExistence(timeout: 10))
        XCTAssertEqual(photo.value as? String, "selected")
        capture("closet-capture-photo-filled", app)
        app.buttons["FIT DETAIL"].tap()
        reachable("잘 맞는 티셔츠", app).tap()
        XCTAssertEqual(element("closet-detail-garment-photo", app).value as? String, "selected")
        capture("closet-capture-photo-reopened", app)
    }

    func testFitLabCaptureAddsPhotoToCloset() {
        let app = launch(balance: 3)
        reachable("fitlab-camera-comparison", app).tap()
        reachable("camera-fit-test-fixture", app).tap()
        reachable("camera-fit-analyze", app).tap()
        XCTAssertTrue(element("camera-fit-unlocked", app).waitForExistence(timeout: 8))
        XCTAssertTrue(element("camera-fit-closet-saved", app).exists)
        reachable("camera-fit-analyze", app).tap()
        XCTAssertTrue(element("coordit-screen-fitlab-result-top", app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["CLOSET"].waitForExistence(timeout: 5))
        app.buttons["CLOSET"].tap()
        reachable("잘 맞는 티셔츠", app).tap()
        let photo = element("closet-detail-garment-photo", app)
        XCTAssertTrue(photo.waitForExistence(timeout: 5))
        XCTAssertEqual(photo.value as? String, "selected")
        capture("fitlab-capture-photo-in-closet", app)
    }

    func testReadableOCRSkipsReviewButSuspiciousValuesRemainEditable() {
        let app = XCUIApplication()
        app.launchArguments = ["--coordit-ui-testing", "--coordit-start-route", "fitlab-input", "--coordit-fitlab-fixture", "ocr-lower"]
        app.launch()
        XCTAssertTrue(element("fitlab-source-ocr", app).waitForExistence(timeout: 5))
        element("fitlab-source-ocr", app).tap()
        capture("simple-ocr-source", app)
        reachable("fitlab-ocr-simulator-fixture", app).tap()
        XCTAssertTrue(element("fitlab-reference-selection", app).waitForExistence(timeout: 5))
        XCTAssertFalse(element("fitlab-ocr-review", app).exists)
        capture("simple-ocr-imported", app)
        app.terminate()
        app.launchArguments = ["--coordit-ui-testing", "--coordit-start-route", "fitlab-input", "--coordit-fitlab-fixture", "ocr-upper"]
        app.launch()
        element("fitlab-source-ocr", app).tap()
        reachable("fitlab-ocr-simulator-fixture", app).tap()
        XCTAssertTrue(element("fitlab-ocr-review", app).waitForExistence(timeout: 5))
        XCTAssertFalse(element("fitlab-reference-selection", app).exists)
        capture("simple-ocr-correction", app)
    }

    func testCardMeasurementUnlocksComparisonAndReportWithOneThread() {
        let app = launch(balance: 3)
        reachable("fitlab-camera-comparison", app).tap()
        XCTAssertTrue(element("camera-fit-screen", app).waitForExistence(timeout: 5))
        reachable("camera-fit-test-fixture", app).tap()
        XCTAssertTrue(element("camera-fit-measurement-chest", app).label.contains("27.0"))
        capture("camera-before-analysis", app)
        XCTAssertTrue(element("camera-fit-analyze", app).exists, app.debugDescription)
        let analyze = reachable("camera-fit-analyze", app)
        XCTAssertTrue(analyze.isEnabled)
        capture("camera-measurement-ready", app)
        analyze.tap()
        XCTAssertTrue(element("camera-fit-unlocked", app).waitForExistence(timeout: 8))
        reachable("camera-fit-size-L", app).tap()
        XCTAssertTrue(element("camera-fit-unlocked", app).label.contains("L"))
        capture("camera-comparison-unlocked", app)
        reachable("camera-fit-analyze", app).tap()
        XCTAssertTrue(element("coordit-screen-fitlab-result-top", app).waitForExistence(timeout: 5))
        XCTAssertEqual(element("coordit-thread-balance-probe", app).label, "2")
        XCTAssertTrue(element("fitlab-add-history", app).exists)
        reachable("fitlab-reopen-camera", app).tap()
        XCTAssertTrue(element("camera-fit-unlocked", app).waitForExistence(timeout: 5))
        XCTAssertEqual(element("coordit-thread-balance-probe", app).label, "2")
    }

    func testZeroBalanceKeepsMeasurementLockedWithoutSavingReference() {
        let app = launch(balance: 0)
        reachable("fitlab-camera-comparison", app).tap()
        reachable("camera-fit-test-fixture", app).tap()
        reachable("camera-fit-analyze", app).tap()
        XCTAssertTrue(element("camera-fit-error", app).waitForExistence(timeout: 5))
        XCTAssertTrue(element("camera-fit-error", app).label.contains("실타래가 부족"))
        XCTAssertFalse(element("camera-fit-unlocked", app).exists)
        capture("camera-insufficient-thread", app)
    }

    func testCameraControlsAtAccessibilityTextSize() {
        let app = launch(balance: 3, contentSize: "UICTContentSizeCategoryAccessibilityXL")
        reachable("fitlab-camera-comparison", app).tap()
        capture("camera-empty-accessibility", app)
        reachable("camera-fit-test-fixture", app).tap()
        XCTAssertTrue(element("camera-fit-analyze", app).isEnabled)
        XCTAssertGreaterThanOrEqual(element("camera-fit-analyze", app).frame.height, 44)
        capture("camera-ready-accessibility", app)
    }

    private func launch(balance: Int, contentSize: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--coordit-ui-testing", "--coordit-start-route", "fitlab-input", "--coordit-fitlab-fixture", "camera-success", "--coordit-thread-balance", String(balance)]
        if let contentSize { app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSize] }
        app.launch()
        XCTAssertTrue(element("fitlab-product-overview", app).waitForExistence(timeout: 5))
        capture(contentSize == nil ? "product-first-use" : "product-first-use-accessibility", app)
        return app
    }

    private func element(_ id: String, _ app: XCUIApplication) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }

    private func reachable(_ id: String, _ app: XCUIApplication) -> XCUIElement {
        let target = element(id, app)
        for _ in 0..<14 {
            let action = element("camera-fit-analyze", app)
            let obscuredByAction = id != "camera-fit-analyze" && action.exists && target.exists && target.frame.midY >= action.frame.minY
            if target.isHittable && !obscuredByAction { break }
            app.swipeUp()
        }
        XCTAssertTrue(target.isHittable, id)
        return target
    }

    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }
}
