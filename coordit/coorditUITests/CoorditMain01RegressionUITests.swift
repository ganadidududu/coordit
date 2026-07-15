#if canImport(XCTest)
import XCTest

final class CoorditMain01RegressionUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testMain01BaselineStillReachable() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--coordit-ui-testing",
            "--coordit-start-route",
            "main01",
        ]
        app.launch()

        XCTAssertTrue(element("main01-screen", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.images["My"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.images["Weather"].waitForExistence(timeout: 5))

        let homeTab = app.buttons["HOME"]
        let fitLabTab = app.buttons["FIT LAB"]
        let closetTab = app.buttons["CLOSET"]

        XCTAssertTrue(homeTab.waitForExistence(timeout: 5))
        XCTAssertTrue(fitLabTab.waitForExistence(timeout: 5))
        XCTAssertTrue(closetTab.waitForExistence(timeout: 5))
        XCTAssertTrue(homeTab.isSelected)
        XCTAssertFalse(fitLabTab.isSelected)
        XCTAssertFalse(closetTab.isSelected)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "main01-baseline-still-reachable"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
}
#endif
