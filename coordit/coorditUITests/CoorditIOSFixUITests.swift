#if canImport(XCTest)
import XCTest

final class CoorditIOSFixUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func element(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func launch(_ route: String, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--coordit-ui-testing", "--coordit-ui-testing-authenticated",
            "--coordit-start-route", route,
            "--coordit-api-base-url", "http://127.0.0.1:45678",
        ] + extra
        app.launch()
        XCTAssertTrue(element("coordit-screen-\(route)", in: app).waitForExistence(timeout: 10))
        return app
    }

    private func capture(_ name: String, app: XCUIApplication) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "\(name)-accessibility"
        tree.lifetime = .keepAlways
        add(tree)
    }

    private func wait(_ predicate: String, for target: XCUIElement) {
        expectation(for: NSPredicate(format: predicate), evaluatedWith: target)
        waitForExpectations(timeout: 10)
    }

    private func reopenProfile(in app: XCUIApplication) {
        app.buttons["프로필 수정 뒤로가기"].tap()
        XCTAssertTrue(element("coordit-screen-mypage-account", in: app).waitForExistence(timeout: 5))
        app.buttons["프로필 수정"].tap()
        XCTAssertTrue(element("mypage-profile-bio", in: app).waitForExistence(timeout: 5))
    }

    func testFeedbackConsentPersistsAfterNavigationAndRelaunch() {
        let app = launch("mypage-privacy", extra: ["--coordit-test-consents", "accepted"])
        let consent = app.buttons["피드백 데이터 개인화 사용 동의"]
        XCTAssertTrue(consent.waitForExistence(timeout: 5))
        wait("enabled == true", for: consent)
        XCTAssertEqual(consent.value as? String, "켜짐")
        consent.tap()
        wait("value == '꺼짐' AND enabled == true", for: consent)
        app.buttons["개인정보/보안 뒤로가기"].tap()
        app.buttons["개인정보/보안"].tap()
        wait("value == '꺼짐' AND enabled == true", for: consent)
        capture("issue-01-consent-reopened", app: app)
        app.terminate()
        app.launchArguments.removeLast(2)
        app.launchArguments += ["--coordit-test-consents", "persisted"]
        app.launch()
        wait("value == '꺼짐' AND enabled == true", for: consent)
    }

    func testProfileFailureShowsErrorWithoutSuccess() {
        let app = launch("mypage-profile-edit")
        app.buttons["mypage-profile-save"].tap()
        let error = element("mypage-profile-save-error", in: app)
        XCTAssertTrue(error.waitForExistence(timeout: 15))
        XCTAssertFalse(element("mypage-profile-saved", in: app).exists)
        XCTAssertTrue(app.buttons["mypage-profile-save"].isEnabled)
        capture("issue-02-profile-save-failure", app: app)
    }

    func testFeedbackConsentUnavailableIsDisabled() {
        let app = launch("mypage-privacy", extra: ["--coordit-test-consents", "unavailable"])
        let consent = app.buttons["피드백 데이터 개인화 사용 동의"]
        XCTAssertTrue(element("mypage-consent-error", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(consent.isEnabled)
        XCTAssertEqual(consent.value as? String, "확인 불가")
        capture("issue-01-consent-unavailable", app: app)
    }

    func testFeedbackConsentSaveFailureKeepsLoadedValue() {
        let app = launch("mypage-privacy", extra: ["--coordit-test-consents", "save-failure"])
        let consent = app.buttons["피드백 데이터 개인화 사용 동의"]
        wait("enabled == true", for: consent)
        let original = consent.value as? String
        consent.tap()
        XCTAssertTrue(element("mypage-consent-error", in: app).waitForExistence(timeout: 5))
        XCTAssertEqual(consent.value as? String, original)
        XCTAssertTrue(consent.isEnabled)
        capture("issue-01-consent-save-failure", app: app)
    }

    func testBiographyEditorStaysAboveKeyboardWithoutBottomNavigation() {
        let app = launch("mypage-profile-edit")
        let bio = element("mypage-profile-bio", in: app)
        XCTAssertTrue(bio.waitForExistence(timeout: 5))
        bio.tap()
        bio.typeText(" Visible")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["FIT LAB"].exists)
        XCTAssertLessThanOrEqual(bio.frame.maxY, app.keyboards.firstMatch.frame.minY)
        capture("issue-04-editor-visible", app: app)
    }

    func testBiographyAndAvatarPersistAfterNavigationAndRelaunch() {
        let app = launch("mypage-profile-edit", extra: ["--coordit-test-local-profile-reset"])
        let bio = element("mypage-profile-bio", in: app)
        XCTAssertTrue(bio.waitForExistence(timeout: 5))
        bio.tap()
        bio.typeText(" Saved biography")
        app.buttons["coordit-keyboard-dismiss"].tap()
        app.buttons["기본 이미지 바꾸기"].tap()
        app.buttons["mypage-profile-save"].tap()
        XCTAssertTrue(element("mypage-profile-save-error", in: app).waitForExistence(timeout: 15))
        reopenProfile(in: app)
        XCTAssertTrue((bio.value as? String)?.contains("Saved biography") == true)
        XCTAssertEqual(element("mypage-profile-avatar", in: app).value as? String, "1")
        capture("issue-03-profile-reopened", app: app)
        app.buttons["프로필 수정 뒤로가기"].tap()
        app.terminate()
        app.launchArguments.removeAll { $0 == "--coordit-test-local-profile-reset" }
        app.launch()
        XCTAssertTrue(bio.waitForExistence(timeout: 5))
        XCTAssertTrue((bio.value as? String)?.contains("Saved biography") == true)
        XCTAssertEqual(element("mypage-profile-avatar", in: app).value as? String, "1")
        capture("issue-03-profile-relaunched", app: app)
        app.buttons["프로필 수정 뒤로가기"].tap()
        app.buttons["mypage-backend-local-logout"].tap()
        wait("exists == false", for: app.buttons["mypage-backend-local-logout"])
        capture("issue-03-profile-logged-out", app: app)
        app.terminate()
        app.launch()
        XCTAssertTrue(bio.waitForExistence(timeout: 5))
        XCTAssertTrue((bio.value as? String)?.contains("Saved biography") == true)
        XCTAssertEqual(element("mypage-profile-avatar", in: app).value as? String, "1")
        capture("issue-03-profile-signed-in-again", app: app)
    }

    func testIssueCaptureMatrix() {
        var app = launch("mypage-privacy", extra: ["--coordit-test-consents", "accepted"])
        capture("issue-01-privacy-top", app: app)
        app.swipeUp()
        capture("issue-01-privacy-end", app: app)
        app.terminate()

        app = launch("mypage-profile-edit", extra: ["--coordit-test-local-profile-reset"])
        capture("issue-03-profile-initial", app: app)
        let bio = element("mypage-profile-bio", in: app)
        XCTAssertTrue(bio.waitForExistence(timeout: 5))
        bio.tap()
        bio.typeText(" Saved biography")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        capture("issue-04-biography-keyboard", app: app)
        app.buttons["coordit-keyboard-dismiss"].tap()
        app.buttons["기본 이미지 바꾸기"].tap()
        app.buttons["mypage-profile-save"].tap()
        let save = app.buttons["mypage-profile-save"]
        wait("enabled == true", for: save)
        capture("issue-02-profile-save-result", app: app)
        reopenProfile(in: app)
        capture("issue-03-profile-reopened", app: app)
        app.terminate()

        app = launch("splash", extra: ["--coordit-ui-testing-onboarding-incomplete"])
        let splash = element("coordit-screen-splash", in: app)
        wait("hittable == true", for: splash)
        splash.tap()
        XCTAssertTrue(element("coordit-onboarding-title", in: app).waitForExistence(timeout: 5))
        capture("issue-05-onboarding-profile", app: app)
        app.buttons["onboarding-next"].tap()
        XCTAssertTrue(app.buttons["나중에 입력하기"].waitForExistence(timeout: 5))
        capture("issue-05-onboarding-measurements", app: app)
        app.buttons["나중에 입력하기"].tap()
        XCTAssertTrue(app.switches["onboarding-consent-terms"].waitForExistence(timeout: 5))
        capture("issue-05-onboarding-consents", app: app)
    }

    func testOnboardingLegalSheetsStayLightAndMainAppearanceRestores() {
        let app = launch("splash", extra: [
            "--coordit-ui-testing-onboarding-incomplete",
            "--coordit-test-onboarding-completion-success",
            "--coordit-server-thread-balance", "3",
        ])
        let splash = element("coordit-screen-splash", in: app)
        wait("hittable == true", for: splash)
        splash.tap()
        XCTAssertTrue(element("coordit-onboarding-title", in: app).waitForExistence(timeout: 5))
        app.buttons["onboarding-next"].tap()
        app.buttons["나중에 입력하기"].tap()
        for index in 0..<2 {
            let open = app.buttons.matching(identifier: "보기").element(boundBy: index)
            XCTAssertTrue(open.waitForExistence(timeout: 5))
            open.tap()
            XCTAssertTrue(app.buttons["닫기"].waitForExistence(timeout: 5))
            capture(index == 0 ? "onboarding-terms-sheet" : "onboarding-privacy-sheet", app: app)
            app.swipeUp()
            capture(index == 0 ? "onboarding-terms-sheet-end" : "onboarding-privacy-sheet-end", app: app)
            app.buttons["닫기"].tap()
            XCTAssertTrue(element("coordit-onboarding-title", in: app).waitForExistence(timeout: 5))
        }
        app.switches["onboarding-consent-terms"].tap()
        app.switches["onboarding-consent-privacy"].tap()
        app.buttons["onboarding-save"].tap()
        XCTAssertTrue(element("coordit-screen-main04", in: app).waitForExistence(timeout: 10))
        capture("onboarding-complete-main-light", app: app)
    }
}
#endif
