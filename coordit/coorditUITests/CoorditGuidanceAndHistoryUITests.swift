import XCTest

final class CoorditGuidanceAndHistoryUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testContextualComparisonHelpExplainsExistingAndNewClothes() {
        let app = launch(extra: ["--coordit-shared-fitlab-url", "https://shop.example/product"])
        tap("fitlab-url-import", app)
        tap("fitlab-show-comparison", app)
        tap("fitlab-tutorial-restart", app)
        XCTAssertTrue(app.staticTexts["내 옷과 비교하는 방법"].waitForExistence(timeout: 5))
        tap("usage-topic-existing", app)
        capture("reference-help-existing", app)
        tap("usage-topic-new", app)
        XCTAssertFalse(element("usage-guide-example", app).exists)
        capture("reference-help-new", app)
        tap("usage-guide-return", app)
        XCTAssertTrue(element("fitlab-reference-selection", app).waitForExistence(timeout: 5))
        XCTAssertEqual(element("coordit-thread-balance-probe", app).label, "0")
    }

    func testRecentHistoryShowsThreeThenCanExpandAndCollapse() {
        let app = launch(fixture: "history-edge", extra: ["--coordit-fitlab-history-namespace", UUID().uuidString, "--coordit-fitlab-history-reset"])
        tap("fitlab-history-seed-retention", app)
        XCTAssertTrue(element("fitlab-history-toggle", app).waitForExistence(timeout: 10))
        XCTAssertFalse(element("fitlab-history-card-analysis-48", app).exists)
        XCTAssertEqual(element("fitlab-history-toggle", app).value as? String, "접힘")
        capture("recent-history-collapsed", app)
        tap("fitlab-history-toggle", app)
        XCTAssertEqual(element("fitlab-history-toggle", app).value as? String, "펼쳐짐")
        let fourth = element("fitlab-history-card-analysis-48", app)
        for _ in 0..<5 where !fourth.isHittable { app.swipeUp() }
        XCTAssertTrue(fourth.exists)
        capture("recent-history-expanded", app)
        // The header toggle remains near the start so collapsing does not require scrolling through every report.
        for _ in 0..<5 where !element("fitlab-history-toggle", app).isHittable { app.swipeDown() }
        tap("fitlab-history-toggle", app)
        XCTAssertTrue(fourth.waitForNonExistence(timeout: 3))
        XCTAssertEqual(element("fitlab-history-toggle", app).value as? String, "접힘")
    }

    private func launch(fixture: String = "url-success", extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--coordit-ui-testing", "--coordit-ui-testing-authenticated", "--coordit-start-route", "fitlab-input", "--coordit-thread-balance", "0", "--coordit-fitlab-fixture", fixture] + extra
        app.launch()
        return app
    }
    private func element(_ id: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }
    private func tap(_ id: String, _ app: XCUIApplication) {
        let target = element(id, app)
        XCTAssertTrue(target.waitForExistence(timeout: 8), id)
        for _ in 0..<10 where !target.isHittable { app.swipeUp() }
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
