#if canImport(XCTest)
import XCTest

final class CoorditFinalSharedSimulatorQAUITests: XCTestCase {
    private let routes = [
        (route: "closet-add-loading", title: "FIT CHECK"),
        (route: "fitlab-input", title: "FIT LAB"),
        (route: "closet-overview", title: "CLOSET"),
        (route: "closet-add-method", title: "ADD CLOTHES"),
        (route: "closet-add-link", title: "LINK INPUT"),
        (route: "closet-add-photo", title: "PHOTO INPUT"),
        (route: "closet-add-manual", title: "MANUAL INPUT"),
        (route: "closet-detail-top", title: "FIT DETAIL"),
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testEightRequestedRoutesRenderExpectedTitlesWithScreenshots() throws {
        for expected in routes {
            let app = launchApp(at: expected.route)
            XCTAssertTrue(
                element("coordit-screen-\(expected.route)", in: app).waitForExistence(timeout: 2),
                "Missing requested route before capture: \(expected.route)"
            )

            let exactTitle = app.buttons[expected.title]
            let fitLabTitle = app.buttons["\(expected.title) 뒤로가기"]
            XCTAssertTrue(
                exactTitle.exists || fitLabTitle.exists,
                "Missing expected shared page title \(expected.title) on \(expected.route)"
            )

            attachScreenshot(named: "route-\(expected.route)", from: app)
            app.terminate()
            XCTAssertTrue(app.wait(for: .notRunning, timeout: 5))
        }
    }

    func testRealSystemPhotosPickerAddsThenReplacesGarmentPhoto() throws {
        let app = launchApp(at: "closet-detail-top")
        XCTAssertTrue(element("coordit-screen-closet-detail-top", in: app).waitForExistence(timeout: 5))

        let photo = element("closet-detail-garment-photo", in: app)
        XCTAssertTrue(photo.waitForExistence(timeout: 5))
        XCTAssertEqual(photo.value as? String, "empty")
        attachScreenshot(named: "picker-before-empty", from: app)

        selectLibraryPhoto(at: 0, using: photo, in: app)
        waitForValue("selected", on: photo)
        let addScreenshot = app.screenshot()
        attachScreenshot(named: "picker-after-add-a", screenshot: addScreenshot)

        selectLibraryPhoto(at: 1, using: photo, in: app)
        waitForValue("selected", on: photo)
        let replaceScreenshot = app.screenshot()
        attachScreenshot(named: "picker-after-replace-b", screenshot: replaceScreenshot)

        XCTAssertNotEqual(
            addScreenshot.pngRepresentation,
            replaceScreenshot.pngRepresentation,
            "Selecting visually distinct media A then B must change the rendered FIT DETAIL frame."
        )
    }

    private func launchApp(at route: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--coordit-ui-testing",
            "--coordit-start-route",
            route,
        ]
        app.launch()
        return app
    }

    private func selectLibraryPhoto(
        at index: Int,
        using photoControl: XCUIElement,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        photoControl.tap()

        let libraryImages = app.images.matching(identifier: "PXGGridLayout-Info")
        XCTAssertTrue(
            libraryImages.firstMatch.waitForExistence(timeout: 10),
            "The real system PhotosPicker grid did not appear.",
            file: file,
            line: line
        )
        XCTAssertGreaterThan(
            libraryImages.count,
            index,
            "The seeded PhotosPicker library does not contain requested fixture index \(index).",
            file: file,
            line: line
        )

        let libraryImage = libraryImages.element(boundBy: index)
        let imageFrame = libraryImage.frame
        let appFrame = app.frame
        app.coordinate(
            withNormalizedOffset: CGVector(
                dx: (imageFrame.midX - appFrame.minX) / appFrame.width,
                dy: (imageFrame.midY - appFrame.minY) / appFrame.height
            )
        ).tap()

        let addButton = app.buttons["Add"]
        let koreanAddButton = app.buttons["추가"]
        if addButton.waitForExistence(timeout: 1) {
            addButton.tap()
        } else if koreanAddButton.exists {
            koreanAddButton.tap()
        }

        XCTAssertTrue(
            photoControl.waitForExistence(timeout: 10),
            "PhotosPicker did not dismiss back to FIT DETAIL.",
            file: file,
            line: line
        )
    }

    private func waitForValue(
        _ expectedValue: String,
        on element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let predicate = NSPredicate(format: "value == %@", expectedValue)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: 10),
            .completed,
            "Expected value \(expectedValue) did not appear.",
            file: file,
            line: line
        )
    }

    private func attachScreenshot(named name: String, from app: XCUIApplication) {
        attachScreenshot(named: name, screenshot: app.screenshot())
    }

    private func attachScreenshot(named name: String, screenshot: XCUIScreenshot) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
}
#endif
