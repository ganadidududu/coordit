#if canImport(XCTest)
import XCTest

final class CoorditTypographyRuntimeUITests: XCTestCase {
    private let fitLabRoutes = [
        (route: "fitlab-input", title: "FIT LAB"),
        (route: "fitlab-loading", title: "FIT LAB"),
        (route: "fitlab-result-top", title: "FIT LAB"),
        (route: "fitlab-result-bottom", title: "FIT LAB"),
        (route: "fitlab-history-register", title: "FIT LAB"),
        (route: "fitlab-history-detail", title: "FIT DETAIL"),
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testBundledGmarketBoldIsAvailableAtRuntime() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--coordit-ui-testing",
            "--coordit-start-route",
            "fitlab-input",
            "--coordit-test-font-diagnostic",
        ]
        app.launch()

        XCTAssertTrue(
            element("coordit-screen-fitlab-input", in: app).waitForExistence(timeout: 5),
            "The intended Fit Lab route must launch before checking font availability."
        )
        let diagnostic = element("coordit-gmarket-bold-font-available", in: app)
        XCTAssertTrue(
            diagnostic.waitForExistence(timeout: 5),
            "The DEBUG font diagnostic must expose the bundled Gmarket Sans Bold availability result."
        )
        XCTAssertEqual(diagnostic.value as? String, "true")
    }

    func testFitLabSharedTitleAppearsOnEveryRoute() throws {
        for expected in fitLabRoutes {
            let app = XCUIApplication()
            app.launchArguments = [
                "--coordit-ui-testing",
                "--coordit-start-route",
                expected.route,
            ]
            app.launch()

            XCTAssertTrue(
                element("coordit-screen-\(expected.route)", in: app).waitForExistence(timeout: 5),
                "Expected Fit Lab route \(expected.route) to launch."
            )
            XCTAssertTrue(
                app.buttons["\(expected.title) 뒤로가기"].waitForExistence(timeout: 2),
                "Expected the shared title \(expected.title) on \(expected.route)."
            )

            app.terminate()
        }
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
}
#endif
