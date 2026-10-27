#if canImport(XCTest)
import XCTest

final class CoorditTutorialExampleUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testFitLabPrerequisiteAndGuideAllowFreeBrowsing() {
        let app = launch(route: "fitlab-input")
        let prerequisite = element("fitlab-reference-prerequisite", app)
        XCTAssertTrue(prerequisite.waitForExistence(timeout: 5))
        for _ in 0..<8 where !element("fitlab-source-example", app).isHittable { app.swipeUp() }
        XCTAssertTrue(prerequisite.isHittable)
        XCTAssertLessThan(element("fitlab-source-manual", app).frame.maxY, prerequisite.frame.minY)
        XCTAssertLessThan(prerequisite.frame.maxY, element("fitlab-source-example", app).frame.minY)
        capture("fitlab-prerequisite-above-example", app)
        tap("fitlab-source-manage-references", app)
        XCTAssertTrue(element("home-reference-done", app).waitForExistence(timeout: 5))
        capture("fitlab-reference-management", app)
        let cancel = app.buttons["취소"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(element("home-reference-done", app).waitForNonExistence(timeout: 5))

        tap("fitlab-tutorial-restart", app)
        XCTAssertTrue(element("fitlab-tutorial-step-0", app).exists)
        XCTAssertTrue(element("fitlab-tutorial-restart", app).isHittable,
                      "도움말을 켜도 읽고 있던 위치가 강제로 이동하면 안 됩니다.")
        capture("fitlab-help-bottom", app)
        for _ in 0..<8 where !prerequisite.isHittable { app.swipeDown() }
        XCTAssertTrue(prerequisite.isHittable)
        XCTAssertTrue(element("fitlab-tutorial-step-0", app).exists)
        capture("fitlab-help-top", app)

        tap("fitlab-source-manual", app)
        let guide = element("fitlab-tutorial-step-3", app)
        XCTAssertTrue(guide.waitForExistence(timeout: 5))
        XCTAssertTrue(guide.isHittable)
        let form = element("fitlab-manual-form", app)
        for _ in 0..<4 { form.swipeUp() }
        XCTAssertFalse(guide.isHittable, "도움말도 입력 폼과 함께 화면 밖으로 스크롤되어야 합니다.")
        XCTAssertTrue(element("fitlab-manual-continue", app).isHittable)
        capture("fitlab-manual-help-scrolled-away", app)
        for _ in 0..<6 where !guide.isHittable { form.swipeDown() }
        XCTAssertTrue(guide.isHittable)
        capture("fitlab-manual-help-returned", app)
    }

    func testClosetGuideScrollsWithFormAndKeepsNavigationAvailable() {
        let app = launch(route: "closet-overview")
        tap("closet-tutorial-restart", app)
        tap("closet-add-garment", app)
        tap("closet-add-method-manual", app)
        let guide = element("closet-tutorial-step-2", app)
        XCTAssertTrue(guide.waitForExistence(timeout: 5))
        for _ in 0..<5 where !guide.isHittable { app.swipeUp() }
        XCTAssertTrue(guide.isHittable)
        let originalY = guide.frame.minY
        app.swipeUp()
        XCTAssertLessThan(guide.frame.minY, originalY - 30)
        capture("closet-help-scroll-down", app)
        app.swipeDown()
        XCTAssertGreaterThan(guide.frame.minY, originalY - 30)
        capture("closet-help-scroll-up", app)
        tap("closet-tutorial-dismiss", app)
        XCTAssertFalse(guide.exists)
    }

    func testClosetExampleCompletesWithoutSaving() {
        let app = launch(route: "closet-add-method")
        tap("closet-method-example", app)
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
        tap("fitlab-source-example", app)
        XCTAssertEqual(app.staticTexts.matching(identifier: "tutorial-example-notice").count, 1)
        capture("fitlab-example-single-notice", app)
        tap("fitlab-url-import", app)
        tap("fitlab-url-confirm", app)
        tap("fitlab-url-continue-to-references", app)
        XCTAssertEqual(app.staticTexts.matching(identifier: "tutorial-example-notice").count, 1)
        tap("fitlab-reference-tutorial-reference", app)
        tap("fitlab-submit-analysis", app)
        XCTAssertTrue(element("fitlab-size-score-M", app).waitForExistence(timeout: 10))
        capture("fitlab-example-result", app)
        XCTAssertFalse(element("fitlab-add-history", app).exists)
        tap("fitlab-example-finish", app)
        XCTAssertTrue(element("fitlab-history-empty", app).waitForExistence(timeout: 5))
        XCTAssertTrue(element("fitlab-source-thread-balance", app).label.contains("0"))
        tap("fitlab-source-manual", app)
        XCTAssertFalse(element("tutorial-example-notice", app).exists)
    }

    func testPhotoAndManualKeepGuidanceInBothFlows() {
        for method in ["photo", "manual"] {
            let app = launch(route: "closet-overview")
            tap("closet-tutorial-restart", app)
            tap("closet-add-garment", app)
            capture("closet-all-methods", app)
            tap("closet-add-method-\(method)", app)
            XCTAssertTrue(element("closet-tutorial-step-2", app).waitForExistence(timeout: 5))
            XCTAssertEqual(app.buttons.matching(identifier: "closet-tutorial-dismiss").count, 1)
            XCTAssertFalse(element("tutorial-example-notice", app).exists)
            capture("closet-\(method)-guide", app)
            app.terminate()
        }
        for method in ["ocr", "manual"] {
            let app = launch(route: "fitlab-input")
            tap("fitlab-tutorial-restart", app)
            capture("fitlab-all-methods", app)
            tap("fitlab-source-\(method)", app)
            XCTAssertTrue(element("fitlab-tutorial-step-3", app).waitForExistence(timeout: 5))
            capture("fitlab-\(method)-guide", app)
            app.terminate()
        }
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
        for _ in 0..<16 where !target.isHittable {
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
#endif
