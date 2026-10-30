import XCTest

final class CoorditHostedARUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testFrozenPhotoCorrectionAndConsentGate() {
        let app = XCUIApplication()
        app.launchArguments = ["--coordit-ar-field-test", "--coordit-hosted-ar-fixture", "--coordit-ui-testing"]
        app.launch()
        let point = element("hosted-ar-point-shoulder_left", app)
        XCTAssertTrue(point.waitForExistence(timeout: 5))
        let shoulder = element("hosted-ar-cm-shoulder", app)
        XCTAssertTrue(app.staticTexts["초안 · 점 확인 필요"].firstMatch.exists)
        capture("hosted-ar-before-correction", app)
        app.buttons["닫기"].tap()
        XCTAssertTrue(app.buttons["결과 버리고 닫기"].waitForExistence(timeout: 3))
        capture("hosted-ar-unsaved-confirmation", app)
        app.buttons["계속 확인"].tap()
        element("hosted-ar-edit-points", app).tap()
        let start = point.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 10, dy: 10)))
        XCTAssertEqual(point.value as? String, "직접 보정")
        XCTAssertTrue(shoulder.exists)
        XCTAssertFalse(app.staticTexts["점 누락·평면 밖 · 직접 보정 필요"].exists)
        element("hosted-ar-edit-points", app).tap()
        capture("hosted-ar-after-correction", app)
        app.buttons["Gemini 3.8"].firstMatch.tap()
        let consent = element("hosted-ar-consent", app)
        for _ in 0..<5 { if consent.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(consent.isHittable)
        XCTAssertEqual(consent.value as? String, "0")
        XCTAssertFalse(element("hosted-ar-infer", app).isEnabled)
        consent.tap()
        XCTAssertEqual(consent.value as? String, "1")
        XCTAssertFalse(element("hosted-ar-infer", app).isEnabled, "Unconfigured simulator must never make paid requests")
        capture("hosted-ar-consent-and-unconfigured-gate", app)
    }

    func testDraftPointsCanBeConfirmedWithoutDraggingOrCallingAPI() {
        let app = XCUIApplication()
        app.launchArguments = ["--coordit-ar-field-test", "--coordit-hosted-ar-fixture", "--coordit-ui-testing"]
        app.launch()
        let point = element("hosted-ar-point-shoulder_left", app)
        XCTAssertTrue(point.waitForExistence(timeout: 5))
        XCTAssertEqual(point.value as? String, "AI 초안")
        capture("hosted-ar-draft-without-moving", app)
        let confirm = element("hosted-ar-confirm-points", app)
        for _ in 0..<5 { if confirm.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(confirm.isHittable)
        confirm.tap()
        XCTAssertEqual(point.value as? String, "사용자 확인")
        XCTAssertFalse(confirm.isEnabled)
        XCTAssertTrue(app.staticTexts["사용자 확인"].firstMatch.exists)
        XCTAssertFalse(element("hosted-ar-infer", app).isEnabled)
        capture("hosted-ar-confirmed-without-moving", app)
    }

    func testMissingPointStaysMissingUntilUserPlacesIt() {
        let app = XCUIApplication()
        app.launchArguments = ["--coordit-ar-field-test", "--coordit-hosted-ar-fixture", "--coordit-ui-testing",
            "--coordit-hosted-ar-missing-point"]
        app.launch()
        let photo = element("hosted-ar-photo", app)
        XCTAssertTrue(photo.waitForExistence(timeout: 5))
        let missing = element("hosted-ar-point-shoulder_left", app)
        XCTAssertFalse(missing.exists)
        capture("hosted-ar-missing-point", app)
        element("hosted-ar-edit-points", app).tap()
        photo.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3)).tap()
        XCTAssertTrue(missing.waitForExistence(timeout: 3))
        XCTAssertEqual(missing.value as? String, "직접 보정")
        capture("hosted-ar-manually-placed-point", app)
    }


    func testExportSheetAndLargeTextRemainUsable() {
        let app = XCUIApplication()
        app.launchArguments = ["--coordit-ar-field-test", "--coordit-hosted-ar-fixture", "--coordit-ui-testing",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"]
        app.launch()
        XCTAssertTrue(element("hosted-ar-model", app).waitForExistence(timeout: 5))
        capture("hosted-ar-large-text-top", app)
        let export = element("hosted-ar-export", app)
        for _ in 0..<30 {
            if export.isHittable { break }
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.75))
            let delta: CGFloat = export.exists && !export.frame.isEmpty && export.frame.midY < 200 ? 180 : -180
            start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: delta)), withVelocity: .slow, thenHoldForDuration: 0.3)
        }
        capture("hosted-ar-large-text-bottom", app)
        XCTAssertTrue(export.isHittable)
        export.tap()
        capture("hosted-ar-export-system-sheet", app)
        XCTAssertTrue(app.buttons["이동"].waitForExistence(timeout: 3) || app.buttons["Export"].exists || app.buttons["취소"].exists || app.buttons["Cancel"].exists || app.buttons["저장"].exists)
        capture("hosted-ar-export-settled", app)
        let save = app.buttons["저장"].exists ? app.buttons["저장"] : app.buttons["Save"]
        save.tap()
        let saved = app.staticTexts["JSON 저장 완료"]
        XCTAssertTrue(save.waitForNonExistence(timeout: 5))
        for _ in 0..<30 { if saved.exists && saved.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        XCTAssertTrue(saved.isHittable)
        capture("hosted-ar-large-text-footer", app)
    }

    private func element(_ id: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let screenshot = app.screenshot()
        try? screenshot.pngRepresentation.write(to: FileManager.default.temporaryDirectory.appendingPathComponent(name + ".png"))
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
