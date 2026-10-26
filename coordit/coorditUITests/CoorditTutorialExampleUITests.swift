#if canImport(XCTest)
import XCTest

final class CoorditTutorialExampleUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testFitLabHelpContainsExampleAndDismissalKeepsInputsAvailable() {
        let app = launch(route: "fitlab-input")
        XCTAssertTrue(element("fitlab-source-url", app).waitForExistence(timeout: 5))
        XCTAssertFalse(element("fitlab-source-example", app).exists)
        XCTAssertFalse(element("fitlab-reference-prerequisite", app).exists)
        XCTAssertLessThan(element("fitlab-tutorial-restart", app).frame.maxY, element("fitlab-source-url", app).frame.minY)
        capture("unified-fitlab-input", app)
        tap("fitlab-tutorial-restart", app)
        XCTAssertTrue(element("usage-guide-example", app).waitForExistence(timeout: 5))
        capture("unified-fitlab-help", app)
        tap("usage-guide-close", app)
        XCTAssertTrue(element("usage-guide-example", app).waitForNonExistence(timeout: 5))
        tap("fitlab-source-manual", app)
        XCTAssertTrue(element("fitlab-manual-form", app).waitForExistence(timeout: 5))
        XCTAssertFalse(element("tutorial-example-notice", app).exists)
    }

    func testClosetHelpAndCompactManualEntryRemainAvailable() {
        let app = launch(route: "closet-overview")
        tap("closet-tutorial-restart", app)
        XCTAssertTrue(element("usage-guide-example", app).waitForExistence(timeout: 5))
        capture("unified-closet-help", app)
        tap("usage-guide-close", app)
        tap("closet-add-garment", app)
        XCTAssertFalse(element("closet-method-example", app).exists)
        XCTAssertTrue(element("closet-add-method-photo", app).exists)
        XCTAssertTrue(element("closet-add-method-link", app).exists)
        let manual = element("closet-add-method-manual", app)
        XCTAssertTrue(manual.exists)
        XCTAssertLessThan(manual.frame.width, element("closet-add-method-link", app).frame.width / 2)
        capture("unified-closet-input", app)
        tap("closet-add-method-manual", app)
        XCTAssertTrue(element("coordit-screen-closet-add-manual", app).waitForExistence(timeout: 5))
        XCTAssertFalse(element("tutorial-example-notice", app).exists)
    }

    func testClosetExampleCompletesWithoutSaving() {
        let app = launch(route: "closet-add-method")
        tap("closet-tutorial-restart", app)
        tap("usage-guide-example", app)
        XCTAssertTrue(element("tutorial-example-notice", app).waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts.matching(identifier: "tutorial-example-notice").count, 1)
        XCTAssertEqual(app.buttons.matching(identifier: "closet-tutorial-dismiss").count, 1)
        XCTAssertFalse(element("closet-example-link", app).exists)
        tap("closet-add-submit", app)
        tap("closet-link-size-row-M", app)
        XCTAssertEqual(app.staticTexts.matching(identifier: "tutorial-example-notice").count, 1)
        XCTAssertEqual(app.buttons.matching(identifier: "closet-tutorial-dismiss").count, 1)
        tap("closet-add-submit", app)
        XCTAssertTrue(element("closet-detail-total-score", app).waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts.matching(identifier: "tutorial-example-notice").count, 1)
        XCTAssertEqual(app.buttons.matching(identifier: "closet-tutorial-dismiss").count, 1)
        capture("closet-example-result", app)
        XCTAssertFalse(element("closet-detail-delete", app).exists)
        tap("closet-example-finish", app)
        tap("closet-add-method-manual", app)
        XCTAssertFalse(element("tutorial-example-notice", app).exists)
    }

    func testFitLabExampleCompletesWithZeroThreadsWithoutHistory() {
        let app = launch(route: "fitlab-input")
        tap("fitlab-tutorial-restart", app)
        tap("usage-guide-example", app)
        XCTAssertEqual(app.staticTexts.matching(identifier: "tutorial-example-notice").count, 1)
        capture("fitlab-example-single-notice", app)
        tap("fitlab-url-import", app)
        XCTAssertTrue(element("fitlab-reference-tutorial-reference", app).waitForExistence(timeout: 5))
        XCTAssertFalse(element("fitlab-url-confirm", app).exists)
        XCTAssertFalse(element("fitlab-url-continue-to-references", app).exists)
        XCTAssertEqual(app.staticTexts.matching(identifier: "tutorial-example-notice").count, 1)
        tap("fitlab-reference-tutorial-reference", app)
        tap("fitlab-submit-analysis", app)
        XCTAssertTrue(element("fitlab-size-score-M", app).waitForExistence(timeout: 10))
        capture("fitlab-example-result", app)
        XCTAssertFalse(element("fitlab-add-history", app).exists)
        tap("fitlab-example-finish", app)
        XCTAssertTrue(element("fitlab-history-empty", app).waitForExistence(timeout: 5))
        XCTAssertEqual(element("coordit-thread-balance-probe", app).label, "0")
        tap("fitlab-source-manual", app)
        XCTAssertFalse(element("tutorial-example-notice", app).exists)
    }

    func testHelpCanBeClosedAtAccessibilityTextSize() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--coordit-ui-testing", "--coordit-ui-testing-authenticated",
            "--coordit-start-route", "fitlab-input",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL",
        ]
        app.launch()
        tap("fitlab-tutorial-restart", app)
        XCTAssertTrue(element("usage-guide-close", app).waitForExistence(timeout: 5))
        capture("unified-help-accessibility", app)
        tap("usage-guide-example", app)
        XCTAssertTrue(element("tutorial-example-notice", app).waitForExistence(timeout: 5))
    }

    private func launch(route: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--coordit-ui-testing", "--coordit-ui-testing-authenticated",
            "--coordit-start-route", route, "--coordit-thread-balance", "0",
        ]
        app.launch()
        return app
    }

    private func element(_ id: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func tap(_ id: String, _ app: XCUIApplication) {
        let target = element(id, app)
        XCTAssertTrue(target.waitForExistence(timeout: 10), id)
        for _ in 0..<16 {
            let coveredByTabBar = !element("usage-guide-close", app).exists && target.frame.maxY > app.frame.maxY - 110
            if target.isHittable && !coveredByTabBar { break }
            if target.frame.midY < app.frame.midY { app.swipeDown() } else { app.swipeUp() }
        }
        XCTAssertTrue(target.isHittable, id)
        if id == "closet-example-finish" { capture("closet-example-finish-visible", app) }
        target.tap()
    }

    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
#endif
