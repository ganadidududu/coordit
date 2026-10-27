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
        XCTAssertTrue(element("closet-camera-kind-lower", app).waitForExistence(timeout: 3))
        capture("simple-closet-category", app)
        element("closet-camera-kind-lower", app).tap()
        element("closet-camera-continue", app).tap()
        XCTAssertTrue(element("camera-fit-screen", app).waitForExistence(timeout: 5))
        XCTAssertFalse(element("camera-fit-guide-pants", app).exists)
        XCTAssertTrue(element("camera-fit-take-photo", app).exists)
        XCTAssertTrue(element("camera-fit-select-photo", app).exists)
        capture("simple-pants-camera", app)
    }

    func testClosetCaptureAutomaticallyFillsGarmentPhoto() {
        let app = XCUIApplication()
        app.launchArguments = ["--coordit-ui-testing", "--coordit-start-route", "closet-add-method", "--coordit-test-closet-save-success"]
        app.launch()
        element("closet-add-method-photo", app).tap()
        element("closet-camera-continue", app).tap()
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

    func testZoomedLandmarkDragFollowsFingerWithoutPanningThePhoto() {
        let app = launch(balance: 3)
        reachable("fitlab-camera-comparison", app).tap()
        reachable("camera-fit-test-fixture", app).tap()
        let photo = element("camera-fit-photo-viewport", app)
        XCTAssertTrue(photo.waitForExistence(timeout: 5))
        photo.pinch(withScale: 1.5, velocity: 1)
        capture("zoomed-before-landmark-drag", app)
        let point = element("camera-fit-point-2", app)
        let zoomText = (photo.value as? String)?.components(separatedBy: "%").first ?? "100"
        let scale = (Double(zoomText) ?? 100) / 100
        let viewportCenter = CGPoint(x: app.frame.midX, y: photo.frame.midY)
        let canvas = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: viewportCenter.x, dy: viewportCenter.y))
        // Zoom may move the selected seam outside the clipped viewport. Pan it back before editing.
        for _ in 0..<6 {
            let dx = viewportCenter.x - point.frame.midX
            let dy = viewportCenter.y - point.frame.midY
            if abs(dx) < 35 && abs(dy) < 35 { break }
            canvas.press(forDuration: 0.1, thenDragTo: canvas.withOffset(CGVector(dx: min(80, max(-80, dx)), dy: min(80, max(-80, dy)))))
        }
        XCTAssertGreaterThan(scale, 1)
        XCTAssertTrue(point.isHittable)
        let initial = point.frame
        let photoBefore = photo.frame
        let start = point.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 30, dy: 0)))
        XCTAssertEqual(point.frame.midX - initial.midX, 30, accuracy: 8, "The displayed landmark must follow the user's finger at zoom")
        XCTAssertEqual(photo.frame.midX, photoBefore.midX, accuracy: 2, "Editing a measurement point must not pan the photo")
        capture("zoomed-landmark-correction", app)
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
