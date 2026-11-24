import XCTest

final class CoorditHomeDesignUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testMagazineReferenceSelectionAndFeatureEntriesRemainFunctional() {
        let app = launch(route: "main04")
        XCTAssertTrue(element("coordit-screen-main04", app).waitForExistence(timeout: 10))
        XCTAssertTrue(element("coordit-main04-banner", app).exists)
        XCTAssertTrue(element("coordit-main04-card-news-black-friday-1", app).exists)
        capture("home-default", app)

        scrollTo("home-reference-select", app).tap()
        let oxford = app.buttons["home-reference-item-oxford"]
        XCTAssertTrue(oxford.waitForExistence(timeout: 5))
        // 시트가 다 올라온 뒤 누르고, 시트 안에서 선택이 반영된 걸 확인한 다음 완료한다.
        let sheetReady = expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: oxford)
        wait(for: [sheetReady], timeout: 5)
        oxford.tap()
        let picked = expectation(for: NSPredicate(format: "isSelected == true"), evaluatedWith: oxford)
        wait(for: [picked], timeout: 5)
        app.buttons["home-reference-done"].tap()
        let oxfordCard = scrollTo("coordit-main04-closet-card-oxford", app)
        let selected = expectation(for: NSPredicate(format: "label CONTAINS %@", "기준 의류"), evaluatedWith: oxfordCard)
        wait(for: [selected], timeout: 5)
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
        XCTAssertTrue(app.staticTexts["전체 1개"].exists)
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
        // 하단 내비가 화면 아래 약 20%를 덮고 있어서, 그 위로 올라와야 누를 수 있는 것으로 본다.
        let reachable = { target.exists && target.isHittable && target.frame.maxY < app.windows.firstMatch.frame.height * 0.8 }
        for _ in 0..<24 where !reachable() {
            let below = !target.exists || target.frame.midY > app.windows.firstMatch.frame.midY
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: below ? 0.65 : 0.42))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: below ? 0.42 : 0.65)))
        }
        XCTAssertTrue(target.waitForExistence(timeout: 5), id)
        XCTAssertTrue(target.isHittable, id)
        Thread.sleep(forTimeInterval: 0.6) // 스냅 애니메이션이 끝난 뒤 누른다.
        return target
    }

    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
