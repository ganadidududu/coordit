#if canImport(XCTest)
import XCTest

final class CoorditClosetAddReadinessUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testPhotoInputSubmitEnablesWithNameAndInjectedSizeChart() throws {
        let app = launchApp(
            at: "closet-add-photo",
            additionalArguments: ["--coordit-test-valid-size-chart"]
        )
        assertScreen("closet-add-photo", in: app)

        let sizeChart = element("closet-size-chart-photo", in: app)
        XCTAssertTrue(sizeChart.waitForExistence(timeout: 5))
        XCTAssertEqual(sizeChart.value as? String, "selected")

        let submit = app.buttons["closet-add-submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        XCTAssertFalse(submit.isEnabled, "A size chart without a garment name must remain disabled.")

        let name = app.textFields["closet-garment-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        focusAndType("Ready Shirt", into: name, in: app)
        app.swipeDown()

        XCTAssertTrue(
            submit.isEnabled,
            "A nonempty name plus the injected valid size chart must enable photo submission without a garment photo."
        )
    }

    func testManualInputRequiresNameAndAllFourMeasurementsWithoutPhoto() throws {
        let app = launchApp(at: "closet-add-manual")
        assertScreen("closet-add-manual", in: app)

        let submit = app.buttons["closet-add-submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        XCTAssertFalse(submit.isEnabled, "An empty manual form must remain disabled.")

        typeText("Ready Pants", into: "closet-garment-name", in: app)
        app.swipeUp()
        XCTAssertFalse(submit.isEnabled, "A garment name without measurements must remain disabled.")

        for index in 0..<4 {
            let field = app.textFields["closet-manual-measurement-\(index)"]
            XCTAssertTrue(field.waitForExistence(timeout: 5), "Missing measurement field \(index).")
            if !field.isHittable {
                app.swipeUp()
            }
            XCTAssertTrue(field.isHittable, "Measurement field \(index) is not hittable.")
            focusAndType("\(index + 1)", into: field, in: app)

            let completedCount = index + 1
            XCTAssertEqual(
                submit.isEnabled,
                completedCount == 4,
                "A name plus \(completedCount) measurements has the wrong readiness state."
            )
        }
    }

    private func launchApp(
        at route: String,
        additionalArguments: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--coordit-ui-testing",
            "--coordit-start-route",
            route,
        ] + additionalArguments
        app.launch()
        return app
    }

    private func assertScreen(
        _ route: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            element("coordit-screen-\(route)", in: app).waitForExistence(timeout: 5),
            "Missing route: \(route)",
            file: file,
            line: line
        )
    }

    private func typeText(_ text: String, into identifier: String, in app: XCUIApplication) {
        let field = element(identifier, in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Missing field: \(identifier)")
        XCTAssertTrue(field.isHittable, "Field is not hittable: \(identifier)")
        focusAndType(text, into: field, in: app)
    }

    private func focusAndType(_ text: String, into field: XCUIElement, in app: XCUIApplication) {
        field.tap()
        if !app.keyboards.firstMatch.waitForExistence(timeout: 2) {
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        XCTAssertTrue(
            app.keyboards.firstMatch.waitForExistence(timeout: 5),
            "The field must gain keyboard focus before typing."
        )
        field.typeText(text)
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
}
#endif
