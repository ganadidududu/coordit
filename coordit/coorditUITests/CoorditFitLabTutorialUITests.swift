#if canImport(XCTest)
import XCTest

final class CoorditFitLabTutorialUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testLinkTutorialCompletesOnlyThroughRealActions() {
        let app = launch()
        start(app)
        step(0, app)
        tap("fitlab-source-url", app)
        step(1, app)
        enterLink(app)
        step(2, app)
        tap("fitlab-url-import", app)
        step(3, app)
        tap("fitlab-url-confirm", app)
        step(4, app)
        tap("fitlab-url-continue-to-references", app)
        step(5, app)
        XCTAssertFalse(element("fitlab-submit-analysis", app).isEnabled)
        tap("fitlab-reference-reference-fixture-tshirt", app)
        step(6, app)
        tap("fitlab-submit-analysis", app)
        step(7, app)
        tap("fitlab-size-score-M", app)
        step(8, app)
        tap("fitlab-add-history", app)
        XCTAssertTrue(element("fitlab-source-url", app).waitForExistence(timeout: 10))
        XCTAssertFalse(element("fitlab-tutorial-step-0", app).exists)
        XCTAssertFalse(element("fitlab-history-empty", app).exists)
        capture("fitlab-tutorial-completed", app)
    }

    func testFailedImportKeepsGuideAndRetryRecovers() {
        let app = launch(fixture: "url-server-error")
        start(app)
        tap("fitlab-source-url", app)
        enterLink(app)
        tap("fitlab-url-import", app)
        XCTAssertTrue(element("fitlab-url-error", app).waitForExistence(timeout: 5))
        step(2, app)
        XCTAssertFalse(element("fitlab-tutorial-step-3", app).exists)
        tap("fitlab-url-import", app)
        step(3, app)
    }

    func testDismissPersistsAndReplayRestarts() {
        let app = launch()
        start(app)
        tap("fitlab-tutorial-dismiss", app)
        app.terminate()
        app.launch()
        XCTAssertTrue(element("fitlab-source-url", app).waitForExistence(timeout: 10))
        XCTAssertFalse(element("fitlab-tutorial-step-0", app).exists)
        start(app)
        step(0, app)
        tap("fitlab-source-manual", app)
        XCTAssertFalse(element("fitlab-tutorial-step-0", app).exists)
    }

    func testLinkInputCanAdvanceWithoutKeyboardReturn() {
        let app = launch()
        start(app)
        tap("fitlab-source-url", app)
        let next = element("fitlab-url-next", app)
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        XCTAssertFalse(next.isEnabled)
        tap("fitlab-url-field", app)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.keyboards.keys["h"].exists, "상품 링크는 영문 키보드로 입력할 수 있어야 합니다.")
        let field = element("fitlab-url-field", app)
        field.typeText("https://shop.example/products/linen-shirt")
        XCTAssertEqual(field.value as? String, "https://shop.example/products/linen-shirt")
        XCTAssertTrue(element("fitlab-tutorial-step-1", app).exists)
        XCTAssertTrue(next.isEnabled)
        tap("fitlab-url-next", app)
        step(2, app)
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertTrue(element("fitlab-url-request-ledger", app).label.contains("prefill=0"))
    }

    private func launch(fixture: String = "url-success") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--coordit-ui-testing", "--coordit-ui-testing-authenticated",
            "--coordit-start-route", "fitlab-input",
            "--coordit-fitlab-fixture", fixture, "--coordit-thread-balance", "5",
            "--coordit-fitlab-history-namespace", "tutorial-\(UUID().uuidString)",
            "--coordit-fitlab-history-reset",
        ]
        app.launch()
        return app
    }

    private func start(_ app: XCUIApplication) {
        tap("fitlab-tutorial-restart", app)
    }

    private func enterLink(_ app: XCUIApplication) {
        tap("fitlab-url-field", app)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10))
        element("fitlab-url-field", app).typeText("https://shop.example/products/linen-shirt")
        XCTAssertTrue(element("fitlab-tutorial-step-1", app).exists)
        element("fitlab-url-field", app).typeText("\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
    }

    private func element(_ id: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func step(_ number: Int, _ app: XCUIApplication) {
        XCTAssertTrue(element("fitlab-tutorial-step-\(number)", app).waitForExistence(timeout: 10))
        capture("fitlab-tutorial-step-\(number)", app)
    }

    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func tap(_ id: String, _ app: XCUIApplication) {
        let target = element(id, app)
        XCTAssertTrue(target.waitForExistence(timeout: 10))
        for _ in 0..<16 {
            if target.isHittable { break }
            if target.frame.midY < app.frame.midY { app.swipeDown() } else { app.swipeUp() }
        }
        XCTAssertTrue(target.isHittable)
        target.tap()
    }
}
#endif
