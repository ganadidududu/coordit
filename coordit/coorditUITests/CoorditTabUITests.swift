#if canImport(XCTest)
import XCTest

final class CoorditTabUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTabsAreTappable() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(element("main01-screen", in: app).waitForExistence(timeout: 5))

        let homeTab = app.buttons["HOME"]
        let fitLabTab = app.buttons["FIT LAB"]
        let closetTab = app.buttons["CLOSET"]

        XCTAssertTrue(homeTab.waitForExistence(timeout: 5))
        XCTAssertTrue(fitLabTab.waitForExistence(timeout: 5))
        XCTAssertTrue(closetTab.waitForExistence(timeout: 5))
        XCTAssertTrue(homeTab.isSelected)
        XCTAssertFalse(fitLabTab.isSelected)
        XCTAssertFalse(closetTab.isSelected)

        fitLabTab.tap()
        XCTAssertTrue(element("coordit-screen-fitlab-input", in: app).waitForExistence(timeout: 5))
        attachScreenshot(named: "fit-lab-tab-after-tap", from: app)

        app.buttons["CLOSET"].tap()
        XCTAssertTrue(element("coordit-screen-closet-overview", in: app).waitForExistence(timeout: 5))
        attachScreenshot(named: "closet-tab-after-tap", from: app)

        app.buttons["HOME"].tap()
        XCTAssertTrue(element("coordit-screen-main04", in: app).waitForExistence(timeout: 5))
    }

    func testDebugLaunchRouteParsingFallsBackOnlyForInvalidRoute() throws {
        let validRoutes = [
            "splash",
            "fitlab-loading",
            "fitlab-result-top",
            "fitlab-result-bottom",
            "fitlab-history-register",
            "fitlab-history-detail",
            "mypage",
            "mypage-thread-charge",
            "mypage-body",
            "mypage-account",
            "mypage-privacy",
            "mypage-app-settings",
            "mypage-notifications",
            "closet-detail-top",
            "closet-detail-bottom",
        ]

        for route in validRoutes {
            let app = launchApp(route: route)
            XCTAssertTrue(
                element("coordit-screen-\(route)", in: app).waitForExistence(timeout: 5),
                "Expected valid route \(route) to render its final screen."
            )
            app.terminate()
        }

        let invalidApp = launchApp(route: "not-a-route")
        XCTAssertTrue(element("main01-screen", in: invalidApp).waitForExistence(timeout: 5))
        XCTAssertFalse(element("coordit-screen-not-a-route", in: invalidApp).exists)
    }

    private func attachScreenshot(named name: String, from app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func launchApp(route: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--coordit-ui-testing",
            "--coordit-start-route",
            route,
        ]
        app.launch()
        return app
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
}
#endif
