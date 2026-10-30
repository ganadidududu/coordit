import XCTest

final class CoorditARFieldUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testManualPointCanBeDraggedBeforeAllMeasurementsAreEntered() {
        let app = XCUIApplication()
        app.launchArguments = ["--coordit-ar-field-test", "--coordit-ui-testing"]
        app.launch()
        let fixture = element("camera-fit-test-fixture", app)
        XCTAssertTrue(fixture.waitForExistence(timeout: 5))
        for _ in 0..<7 { if fixture.isHittable { break }; app.swipeUp() }
        fixture.tap()
        let manual = element("camera-fit-manual-points", app)
        for _ in 0..<7 { if manual.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(manual.isHittable)
        manual.tap()
        let photo = element("camera-fit-photo-viewport", app)
        let usable = CGRect(x: app.frame.minX, y: 180, width: app.frame.width, height: app.frame.height - 380)
        for _ in 0..<7 {
            if photo.frame.intersection(usable).height > 60 { break }
            if photo.frame.minY < usable.minY { app.swipeDown() } else { app.swipeUp() }
        }
        let visible = photo.frame.intersection(usable)
        XCTAssertGreaterThan(visible.height, 60)
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: visible.midX, dy: visible.midY)).tap()
        let first = element("camera-fit-point-0", app)
        XCTAssertTrue(first.waitForExistence(timeout: 3), "The first manual point needs a handle before all eight exist")
        XCTAssertFalse(element("camera-fit-point-1", app).exists)
        let before = first.frame.midX
        let start = first.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 20, dy: 0)))
        XCTAssertEqual(first.frame.midX - before, 20, accuracy: 5)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "manual-point-correction-before-complete-simulator"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testLocalFieldCollectionKeepsAutomaticAndManualStagesWithoutBilling() {
        let app = XCUIApplication()
        app.launchArguments = ["--coordit-ar-field-test", "--coordit-ui-testing"]
        app.launch()
        XCTAssertTrue(element("ar-field-settings", app).waitForExistence(timeout: 5))
        XCTAssertFalse(element("camera-fit-analyze", app).exists)
        element("ar-field-settings", app).tap()
        let fields = [
            ("garment-id", "simulator-fixture"), ("background", "fixture"), ("lighting", "fixture"),
            ("truth-shoulder_width", "40"), ("truth-chest_width", "40"),
            ("truth-total_length", "60"), ("truth-sleeve_length", "20")
        ]
        for (key, value) in fields {
            let input = element("ar-field-\(key)", app)
            for _ in 0..<5 {
                if input.isHittable { break }
                let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.45))
                start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -180)))
            }
            input.tap(); input.typeText(value)
        }
        app.buttons["완료"].tap()
        let fixture = element("camera-fit-test-fixture", app)
        for _ in 0..<6 { if fixture.isHittable { break }; app.swipeUp() }
        fixture.tap()
        element("ar-field-automatic", app).tap()
        XCTAssertEqual(element("ar-field-export", app).value as? String, "1")
        element("ar-field-manual", app).tap()
        XCTAssertEqual(element("ar-field-export", app).value as? String, "2")
        XCTAssertFalse(element("camera-fit-analyze", app).exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "ar-field-local-collection-simulator-not-sensor-accuracy"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    private func element(_ id: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }
}
