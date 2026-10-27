import XCTest

final class CoorditHomeDesignUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testMagazineReferenceSelectionAndFeatureEntriesRemainFunctional() {
        let app = launch(route: "main04")
        XCTAssertTrue(element("coordit-screen-main04", app).waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["최근 저장 0개"].exists)
        app.buttons["매거진 2페이지"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "기준이 되니까")).firstMatch.exists)
        capture("home-magazine-page-2", app)
        app.buttons["매거진 3페이지"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "나답게")).firstMatch.exists)
        capture("home-magazine-page-3", app)
        app.buttons["매거진 1페이지"].tap()
        capture("home-default", app)

        scrollTo("home-reference-select", app).tap()
        let oxford = app.buttons["home-reference-item-oxford"]
        XCTAssertTrue(oxford.waitForExistence(timeout: 5))
        oxford.tap()
        app.buttons["home-reference-done"].tap()
        XCTAssertTrue(app.staticTexts["선택한 기준 의류 1개를 핏 계산에 사용해요."].waitForExistence(timeout: 5))
        capture("home-selected-reference", app)

        scrollTo("coordit-main04-new-fit-button", app).tap()
        XCTAssertTrue(element("coordit-screen-fitlab-input", app).waitForExistence(timeout: 5))
        app.buttons["HOME"].tap()
        scrollTo("coordit-main04-closet-button", app).tap()
        XCTAssertTrue(element("coordit-screen-closet-overview", app).waitForExistence(timeout: 5))
    }

    func testSavedReportStillOpensItsExactDetailFromHome() {
        let args = ["--coordit-fitlab-fixture", "history-persistence", "--coordit-fitlab-history-namespace", UUID().uuidString]
        var app = launch(route: "fitlab-result-top", extra: args)
        scrollTo("fitlab-add-history", app).tap()
        XCTAssertTrue(element("coordit-screen-fitlab-input", app).waitForExistence(timeout: 5))
        app.terminate()
        app = launch(route: "main04", extra: args)
        let report = scrollTo("coordit-main04-history-card-analysis-fixture-upper", app)
        XCTAssertTrue(report.label.contains("92"))
        XCTAssertTrue(app.staticTexts["최근 저장 1개"].exists)
        capture("home-saved-report", app)
        report.tap()
        XCTAssertTrue(element("coordit-screen-fitlab-history-detail", app).waitForExistence(timeout: 5))
        XCTAssertEqual(element("fitlab-history-detail-analysis", app).label, "analysis-fixture-upper")
    }

    private func launch(route: String, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--coordit-ui-testing", "--coordit-start-route", route] + extra
        app.launch()
        return app
    }

    private func element(_ id: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func scrollTo(_ id: String, _ app: XCUIApplication) -> XCUIElement {
        let target = element(id, app)
        for _ in 0..<24 where !target.exists || !target.isHittable {
            let below = !target.exists || target.frame.midY > app.windows.firstMatch.frame.midY
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: below ? 0.65 : 0.42))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: below ? 0.42 : 0.65)))
        }
        XCTAssertTrue(target.waitForExistence(timeout: 5), id)
        XCTAssertTrue(target.isHittable, id)
        return target
    }

    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
