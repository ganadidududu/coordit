import XCTest

final class CoorditFirstUseGuidanceUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testFirstLoginGuidesRequireSkipConfirmationAndDoNotRepeat() {
        let account = UUID().uuidString
        let app = launch(account: account)
        for title in ["핏 랩 사용법", "옷장 사용법"] {
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 8))
            tap("usage-guide-close", app)
            let alert = app.alerts["처음이라면 따라 해보는 걸 추천해요"]
            XCTAssertTrue(alert.waitForExistence(timeout: 3))
            XCTAssertTrue(alert.buttons["따라 해볼게요"].exists)
            capture("first-use-skip-confirmation", app)
            alert.buttons["이번에는 건너뛰기"].tap()
        }
        XCTAssertTrue(element("usage-guide-sheet", app).waitForNonExistence(timeout: 5))
        app.terminate()
        let relaunched = launch(account: account)
        XCTAssertTrue(element("coordit-main04-banner", relaunched).waitForExistence(timeout: 5))
        XCTAssertFalse(element("first-use-guide-introduction", relaunched).waitForExistence(timeout: 2))
    }

    func testFirstLoginCanCompleteBothExamplesWithoutChargeOrSavedClothes() {
        let app = launch(account: UUID().uuidString)
        XCTAssertTrue(app.staticTexts["핏 랩 사용법"].waitForExistence(timeout: 8))
        capture("first-use-fitlab-guide", app)
        tap("usage-guide-example", app)
        tap("fitlab-url-import", app)
        tap("fitlab-show-comparison", app)
        tap("fitlab-choose-closet", app)
        tap("fitlab-reference-tutorial-reference", app)
        tap("fitlab-reference-picker-done", app)
        tap("fitlab-submit-analysis", app)
        XCTAssertTrue(element("fitlab-size-score-M", app).waitForExistence(timeout: 10))
        tap("fitlab-example-finish", app)
        XCTAssertTrue(app.staticTexts["옷장 사용법"].waitForExistence(timeout: 8))
        capture("first-use-closet-guide", app)
        tap("usage-guide-example", app)
        tap("closet-add-submit", app)
        tap("closet-link-size-row-M", app)
        tap("closet-add-submit", app)
        XCTAssertTrue(element("closet-detail-total-score", app).waitForExistence(timeout: 8))
        XCTAssertFalse(element("closet-detail-delete", app).exists)
        tap("closet-example-finish", app)
        XCTAssertTrue(element("coordit-main04-banner", app).waitForExistence(timeout: 8))
        app.buttons["FIT LAB"].tap()
        XCTAssertTrue(element("fitlab-history-empty", app).waitForExistence(timeout: 5))
        XCTAssertEqual(element("coordit-thread-balance-probe", app).label, "0")
        XCTAssertFalse(element("tutorial-example-notice", app).exists)
    }

    func testLeavingPracticeConfirmsSkipAndRestoresSharedProductLink() {
        let account = UUID().uuidString
        let originalURL = "https://shop.example/my-original-product"
        let app = launch(account: account, extra: ["--coordit-shared-fitlab-url", originalURL])
        tap("usage-guide-example", app)
        XCTAssertTrue(element("fitlab-url-import", app).waitForExistence(timeout: 8))
        tap("fitlab-tutorial-dismiss", app)
        let alert = app.alerts["처음이라면 끝까지 따라 해보는 걸 추천해요"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        alert.buttons["계속 따라하기"].tap()
        XCTAssertTrue(element("fitlab-url-import", app).exists)
        app.buttons["FIT LAB 뒤로가기"].tap()
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        alert.buttons["이번에는 건너뛰기"].tap()
        XCTAssertTrue(app.staticTexts["옷장 사용법"].waitForExistence(timeout: 8))
        tap("usage-guide-close", app)
        app.alerts["처음이라면 따라 해보는 걸 추천해요"].buttons["이번에는 건너뛰기"].tap()
        XCTAssertTrue(element("usage-guide-sheet", app).waitForNonExistence(timeout: 5))
        XCTAssertEqual(element("fitlab-url-field", app).value as? String, originalURL)
        XCTAssertFalse(element("tutorial-example-notice", app).exists)
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
        for _ in 0..<12 where !target.isHittable { app.swipeUp() }
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
