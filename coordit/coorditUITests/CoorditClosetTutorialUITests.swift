#if canImport(XCTest)
import XCTest

final class CoorditClosetTutorialUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testRealActionsAdvanceAndSuccessfulScoreCanComplete() {
        let app = launch(extra: [
            "--coordit-fitlab-fixture", "url-default",
            "--coordit-test-closet-save-success", "--coordit-test-closet-tutorial-score",
        ])
        start(app)
        assertStep(0, app)
        tap("closet-add-garment", app)
        assertStep(1, app)
        tap("closet-add-method-link", app)
        assertStep(2, app)
        let field = app.textFields["closet-product-link"]
        field.tap()
        field.typeText("https://shop.example/products/linen-shirt")
        XCTAssertTrue(element("closet-tutorial-step-2", app).exists)
        field.typeText("\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        assertStep(3, app)
        XCTAssertFalse(element("closet-tutorial-step-4", app).exists)
        tap("closet-add-submit", app)
        assertStep(4, app)
        XCTAssertFalse(app.buttons["closet-add-submit"].isEnabled)
        tap("closet-link-size-row-M", app)
        assertStep(5, app)
        tap("closet-add-submit", app)
        assertStep(6, app)
        XCTAssertTrue(element("closet-detail-total-score", app).exists)
        tap("closet-tutorial-finish", app)
        XCTAssertFalse(element("closet-tutorial-step-6", app).exists)
    }

    func testFailedAnalysisDoesNotAdvanceToSizeSelection() {
        let app = launch(extra: ["--coordit-test-link-extraction-failure"])
        start(app)
        tap("closet-add-garment", app)
        tap("closet-add-method-link", app)
        assertStep(3, app)
        tap("closet-add-submit", app)
        XCTAssertTrue(element("closet-link-extraction-error", app).waitForExistence(timeout: 5))
        assertStep(3, app)
        XCTAssertFalse(element("closet-tutorial-step-4", app).exists)
    }

    func testDismissAndReplay() {
        let app = launch(extra: [])
        start(app)
        assertStep(0, app)
        tap("closet-tutorial-dismiss", app)
        XCTAssertFalse(element("closet-tutorial-step-0", app).exists)
        tap("closet-tutorial-restart", app)
        assertStep(0, app)
    }

    private func launch(extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--coordit-ui-testing", "--coordit-ui-testing-authenticated", "--coordit-start-route", "closet-overview"] + extra
        app.launch()
        return app
    }

private func start(_ app: XCUIApplication) {
    let replay = element("closet-tutorial-restart", app)
    for _ in 0..<8 where !replay.isHittable { app.swipeUp() }
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = "closet-replay-below-garments"
    attachment.lifetime = .keepAlways
    add(attachment)
    tap("closet-tutorial-restart", app)
}

    private func element(_ id: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func assertStep(_ step: Int, _ app: XCUIApplication) {
XCTAssertTrue(element("closet-tutorial-step-\(step)", app).waitForExistence(timeout: 10))
let attachment = XCTAttachment(screenshot: app.screenshot())
attachment.name = "closet-spotlight-step-\(step)"
attachment.lifetime = .keepAlways
add(attachment)
    }

    private func tap(_ id: String, _ app: XCUIApplication) {
        let target = element(id, app)
        XCTAssertTrue(target.waitForExistence(timeout: 10))
        for _ in 0..<6 where !target.isHittable {
            if target.frame.midY < app.frame.midY { app.swipeDown() } else { app.swipeUp() }
        }
        target.tap()
    }
}
#endif
