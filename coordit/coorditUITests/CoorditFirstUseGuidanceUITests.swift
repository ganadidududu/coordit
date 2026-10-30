import XCTest

final class CoorditFirstUseGuidanceUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testLoginDoesNotShowHelpAndEachFeatureStartsItsOwnPracticeOnce() {
        let account = UUID().uuidString
        let app = launch(account: account)
        XCTAssertTrue(element("coordit-main04-banner", app).waitForExistence(timeout: 8))
        XCTAssertFalse(element("usage-guide-sheet", app).exists)
        XCTAssertFalse(element("tutorial-example-notice", app).exists)
        capture("login-home-no-guide", app)
        app.buttons["CLOSET"].tap()
        startIntroductionIfOffered(app)
        XCTAssertTrue(element("closet-product-link", app).waitForExistence(timeout: 8))
        XCTAssertEqual(element("closet-product-link", app).value as? String, "https://example.coordit.invalid/products/basic")
        XCTAssertFalse(element("usage-guide-sheet", app).exists)
        XCTAssertFalse(element("closet-product-link", app).isEnabled)
        XCTAssertTrue(element("closet-tutorial-step-3", app).waitForExistence(timeout: 8))
        capture("first-closet-entry", app)
        completeClosetExample(app)
        tap("closet-example-finish", app)
        XCTAssertTrue(element("closet-add-garment", app).waitForExistence(timeout: 8))
        app.buttons["HOME"].tap()
        XCTAssertFalse(element("usage-guide-sheet", app).exists)
        app.buttons["FIT LAB"].tap()
        startIntroductionIfOffered(app)
        XCTAssertTrue(element("fitlab-url-import", app).waitForExistence(timeout: 8))
        XCTAssertTrue(element("fitlab-tutorial-dismiss", app).waitForExistence(timeout: 8))
        capture("first-fitlab-entry", app)
        tap("fitlab-tutorial-dismiss", app)
        let alert = app.alerts["처음이라면 끝까지 따라 해보는 걸 추천해요"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        capture("practice-skip-confirmation", app)
        alert.buttons["계속 따라하기"].tap()
        XCTAssertTrue(element("fitlab-url-import", app).exists)
        tap("fitlab-tutorial-dismiss", app)
        alert.buttons["이번에는 건너뛰기"].tap()
        XCTAssertTrue(element("fitlab-source-url", app).waitForExistence(timeout: 8))
        XCTAssertFalse(element("usage-guide-sheet", app).exists)
        app.terminate()
        let relaunched = launch(account: account)
        XCTAssertTrue(element("coordit-main04-banner", relaunched).waitForExistence(timeout: 8))
        relaunched.buttons["FIT LAB"].tap()
        XCTAssertTrue(element("fitlab-source-url", relaunched).waitForExistence(timeout: 8))
        XCTAssertFalse(element("tutorial-example-notice", relaunched).exists)
        relaunched.buttons["CLOSET"].tap()
        XCTAssertTrue(element("closet-add-garment", relaunched).waitForExistence(timeout: 8))
        XCTAssertFalse(element("usage-guide-sheet", relaunched).exists)
    }

    func testFirstFitLabPracticeIncludesMissingReferenceRegistrationWithoutChargeOrSave() {
        let app = launch(account: UUID().uuidString)
        app.buttons["FIT LAB"].tap()
        startIntroductionIfOffered(app)
        tap("fitlab-url-import", app)
        XCTAssertTrue(element("fitlab-free-summary", app).waitForExistence(timeout: 8))
        let hint = element("fitlab-tutorial-step-4", app)
        XCTAssertLessThan(hint.frame.maxY, element("fitlab-show-comparison", app).frame.minY)
        capture("practice-free-summary", app)
        tap("fitlab-show-comparison", app)
        tap("fitlab-camera-comparison", app)
        let camera = app.alerts["카메라 측정 기능은 준비 중입니다!"]
        XCTAssertTrue(camera.waitForExistence(timeout: 3))
        capture("practice-camera-unavailable", app)
        camera.buttons["확인"].tap()
        tap("fitlab-choose-closet", app)
        XCTAssertTrue(element("fitlab-reference-picker-empty", app).waitForExistence(timeout: 5))
        capture("practice-empty-wardrobe", app)
        tap("fitlab-reference-picker-close", app)
        tap("fitlab-manage-references", app)
        XCTAssertTrue(element("closet-tutorial-step-3", app).waitForExistence(timeout: 8))
        app.buttons["FIT LAB"].tap()
        startIntroductionIfOffered(app)
        let exit = app.alerts["처음이라면 끝까지 따라 해보는 걸 추천해요"]
        XCTAssertTrue(exit.waitForExistence(timeout: 3))
        exit.buttons["계속 따라하기"].tap()
        completeClosetExample(app, returnToFitLab: true)
        XCTAssertTrue(element("fitlab-choose-closet", app).waitForExistence(timeout: 8))
        capture("practice-reference-return", app)
        XCTAssertTrue(element("fitlab-selected-reference-summary", app).exists)
        XCTAssertTrue(element("fitlab-submit-analysis", app).isEnabled)
        XCTAssertFalse(element("fitlab-reference-picker", app).exists)
        capture("practice-reference-auto-selected", app)
        tap("fitlab-submit-analysis", app)
        XCTAssertTrue(element("fitlab-size-score-M", app).waitForExistence(timeout: 10))
        XCTAssertFalse(element("fitlab-add-history", app).exists)
        XCTAssertEqual(element("coordit-thread-balance-probe", app).label, "0")
        capture("practice-result", app)
        tap("fitlab-example-finish", app)
        XCTAssertTrue(element("fitlab-source-url", app).waitForExistence(timeout: 8))
        XCTAssertFalse(element("usage-guide-sheet", app).exists)
        app.buttons["CLOSET"].tap()
        startIntroductionIfOffered(app)
        XCTAssertTrue(element("closet-add-garment", app).waitForExistence(timeout: 8))
        XCTAssertFalse(element("tutorial-example-notice", app).exists)
        XCTAssertFalse(app.staticTexts["[예시] 베이직 티셔츠"].exists)
    }

    func testSharedProductWaitsBehindPracticeAndReturnsWithoutStartingClosetHelp() {
        let originalURL = "https://shop.example/my-original-product"
        let app = launch(account: UUID().uuidString, extra: ["--coordit-shared-fitlab-url", originalURL])
        startIntroductionIfOffered(app)
        tap("fitlab-url-import", app)
        XCTAssertTrue(element("fitlab-free-summary", app).waitForExistence(timeout: 8))
        tap("fitlab-tutorial-dismiss", app)
        app.alerts["처음이라면 끝까지 따라 해보는 걸 추천해요"].buttons["이번에는 건너뛰기"].tap()
        XCTAssertTrue(element("fitlab-url-field", app).waitForExistence(timeout: 8))
        XCTAssertEqual(element("fitlab-url-field", app).value as? String, originalURL)
        XCTAssertFalse(element("usage-guide-sheet", app).exists)
        XCTAssertFalse(element("tutorial-example-notice", app).exists)
    }

    func testFreeReportCanScrollPastCompactCoachAtAccessibilitySize() {
        let app = launch(account: UUID().uuidString, extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"])
        app.buttons["FIT LAB"].tap()
        startIntroductionIfOffered(app)
        tap("fitlab-url-import", app)
        XCTAssertTrue(element("fitlab-free-summary", app).waitForExistence(timeout: 8))
        capture("practice-free-summary-large-start", app)
        XCTAssertFalse(element("fitlab-summary-highlight", app).exists)
        XCTAssertFalse(element("fitlab-show-comparison", app).isHittable)
        app.swipeUp()
        capture("practice-free-summary-large-scrolled", app)
        let compare = element("fitlab-show-comparison", app)
        for _ in 0..<14 {
            if compare.isHittable && compare.frame.maxY < app.frame.maxY - 110 { break }
            app.swipeUp()
        }
        XCTAssertFalse(element("fitlab-tutorial-step-4", app).isHittable)
        XCTAssertTrue(compare.isHittable)
        let edit = element("fitlab-edit-product", app)
        XCTAssertTrue(edit.isHittable)
        XCTAssertLessThan(edit.frame.maxY, compare.frame.minY)
        capture("practice-free-summary-large-end", app)
        tap("fitlab-show-comparison", app)
        XCTAssertTrue(element("fitlab-reference-selection", app).waitForExistence(timeout: 5))
    }

    func testHelpReplayReturnsToOriginalFreeReportAfterNestedReferencePractice() {
        let app = launch(account: UUID().uuidString)
        app.buttons["FIT LAB"].tap()
        startIntroductionIfOffered(app)
        tap("fitlab-tutorial-dismiss", app)
        app.alerts["처음이라면 끝까지 따라 해보는 걸 추천해요"].buttons["이번에는 건너뛰기"].tap()
        tap("fitlab-source-url", app)
        let url = element("fitlab-url-field", app)
        XCTAssertTrue(url.waitForExistence(timeout: 5))
        url.tap()
        url.typeText("https://shop.example/original")
        tap("fitlab-url-import", app)
        XCTAssertTrue(element("fitlab-free-summary", app).waitForExistence(timeout: 8))
        tap("fitlab-tutorial-restart", app)
        capture("help-on-demand", app)
        tap("usage-guide-example", app)
        tap("fitlab-url-import", app)
        tap("fitlab-show-comparison", app)
        tap("fitlab-choose-closet", app)
        XCTAssertTrue(element("fitlab-reference-picker-empty", app).waitForExistence(timeout: 5))
        tap("fitlab-reference-picker-close", app)
        tap("fitlab-manage-references", app)
        completeClosetExample(app, returnToFitLab: true)
        XCTAssertTrue(element("fitlab-choose-closet", app).waitForExistence(timeout: 8))
        tap("fitlab-tutorial-dismiss", app)
        app.alerts["처음이라면 끝까지 따라 해보는 걸 추천해요"].buttons["이번에는 건너뛰기"].tap()
        XCTAssertTrue(element("fitlab-free-summary", app).waitForExistence(timeout: 8))
        XCTAssertFalse(element("usage-guide-sheet", app).exists)
        XCTAssertFalse(element("tutorial-example-notice", app).exists)
        capture("help-replay-restored-report", app)
        app.buttons["CLOSET"].tap()
        startIntroductionIfOffered(app)
        XCTAssertTrue(element("closet-add-garment", app).waitForExistence(timeout: 8))
    }

    func testDeferringIntroductionPreservesSharedProductAndKeepsClosetIndependent() {
        let originalURL = "https://shop.example/preserved-product"
        let app = launch(account: UUID().uuidString, extra: ["--coordit-shared-fitlab-url", originalURL])
        XCTAssertTrue(element("practice-introduction", app).waitForExistence(timeout: 8))
        XCTAssertFalse(element("tutorial-example-notice", app).exists)
        capture("intro-fitlab-before-start", app)
        tap("practice-intro-later", app)
        XCTAssertTrue(element("fitlab-url-field", app).waitForExistence(timeout: 8))
        XCTAssertEqual(element("fitlab-url-field", app).value as? String, originalURL)
        XCTAssertFalse(element("tutorial-example-notice", app).exists)
        capture("intro-deferred-shared-product", app)
        app.buttons["HOME"].tap()
        app.buttons["FIT LAB"].tap()
        XCTAssertFalse(element("practice-introduction", app).waitForExistence(timeout: 2))
        app.buttons["CLOSET"].tap()
        XCTAssertTrue(element("practice-introduction", app).waitForExistence(timeout: 8))
        capture("intro-closet-before-start", app)
        tap("practice-intro-later", app)
        XCTAssertTrue(element("closet-add-garment", app).waitForExistence(timeout: 8))
        XCTAssertFalse(element("tutorial-example-notice", app).exists)
    }

    private func startIntroductionIfOffered(_ app: XCUIApplication) {
        guard element("practice-introduction", app).waitForExistence(timeout: 1.5) else { return }
        XCTAssertFalse(element("tutorial-example-notice", app).exists)
        let name = app.staticTexts["옷장 등록, 예시로 함께 해볼까요?"].exists ? "first-closet-introduction" : "first-fitlab-introduction"
        capture(name + (app.launchArguments.contains("UICTContentSizeCategoryAccessibilityXL") ? "-large" : ""), app)
        if app.launchArguments.contains("UICTContentSizeCategoryAccessibilityXL") {
            for _ in 0..<6 {
                if element("practice-intro-step-3", app).isHittable { break }
                app.swipeUp()
            }
            XCTAssertTrue(element("practice-intro-step-3", app).isHittable)
            capture(name + "-large-end", app)
        }
        tap("practice-intro-start", app)
    }

    private func completeClosetExample(_ app: XCUIApplication, returnToFitLab: Bool = false) {
        XCTAssertTrue(element("closet-tutorial-step-3", app).waitForExistence(timeout: 8))
        tap("closet-add-submit", app)
        XCTAssertTrue(element("closet-tutorial-step-4", app).waitForExistence(timeout: 8))
        tap("closet-link-size-row-M", app)
        XCTAssertTrue(element("closet-tutorial-step-5", app).waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 0.8)
        XCTAssertLessThanOrEqual(element("closet-link-size-row-M", app).frame.maxY, element("closet-link-size-row-L", app).frame.minY)
        capture("closet-practice-size", app)
        tap("closet-add-submit", app)
        if returnToFitLab {
            XCTAssertTrue(element("fitlab-selected-reference-summary", app).waitForExistence(timeout: 8))
            XCTAssertFalse(element("closet-example-finish", app).exists)
            return
        }
        XCTAssertTrue(element("closet-detail-total-score", app).waitForExistence(timeout: 8))
        XCTAssertTrue(element("closet-tutorial-step-6", app).exists)
        XCTAssertFalse(element("closet-detail-delete", app).exists)
        capture("closet-practice-result", app)
    }

    private func launch(account: String, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--coordit-ui-testing", "--coordit-ui-testing-authenticated", "--coordit-start-route", "main04", "--coordit-thread-balance", "0", "--coordit-fitlab-fixture", "url-success", "--coordit-test-first-use-guides", "--coordit-tutorial-account", account] + extra
        app.launch()
        return app
    }
    private func element(_ id: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }
    private func tap(_ id: String, _ app: XCUIApplication) {
        let target = element(id, app)
        XCTAssertTrue(target.waitForExistence(timeout: 8), id)
        for _ in 0..<16 {
            let sheet = element("practice-introduction", app).exists || element("usage-guide-close", app).exists || element("fitlab-reference-picker", app).exists
            let covered = !sheet && target.frame.maxY > app.frame.maxY - 110
            if target.isHittable && !covered { break }
            if target.frame.midY < app.frame.midY { app.swipeDown() } else { app.swipeUp() }
        }
        XCTAssertTrue(target.isHittable, id)
        target.tap()
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        Thread.sleep(forTimeInterval: 0.8)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
