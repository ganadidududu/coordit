import XCTest

final class CoorditGuestAndRecoveryUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testGuestChoiceExplainsNoGrantAndStartsAtZero() {
        let app = launch(route: "splash", authenticated: false, extra: ["--coordit-ui-testing-clear-persisted-session", "--coordit-test-guest-bootstrap", "--coordit-welcome-state", "fresh"])
        tap("splash-signup-entry", app)
        XCTAssertEqual(element("splash-auth-guest", app).label, "비회원으로 둘러보기")
        tap("splash-auth-guest", app)
        let alert = app.alerts["비회원으로 둘러볼까요?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        XCTAssertTrue(alert.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "광고를 보고 충전")).firstMatch.exists)
        capture("guest-welcome-policy", app)
        alert.buttons["로그인하기"].tap()
        XCTAssertTrue(element("splash-auth-google", app).exists)
        tap("splash-auth-guest", app)
        alert.buttons["비회원으로 둘러보기"].tap()
        XCTAssertTrue(element("coordit-screen-main04", app).waitForExistence(timeout: 8))
        app.buttons["FIT LAB"].tap()
        XCTAssertEqual(element("coordit-thread-balance-probe", app).label, "0")
        app.terminate()
    }

    func testGuestCanEarnFirstThreadByWatchingAd() {
        let app = launch(route: "mypage-thread-charge", extra: ["--coordit-ui-testing-guest", "--coordit-rewarded-ad-fixture", "credited"])
        XCTAssertTrue(app.staticTexts["0 실타래"].waitForExistence(timeout: 5))
        let ad = element("coordit-thread-charge-ad-cta", app)
        XCTAssertTrue(NSPredicate(format: "enabled == true").evaluate(with: ad))
        tap("coordit-thread-charge-ad-cta", app)
        XCTAssertTrue(app.staticTexts["1 실타래"].waitForExistence(timeout: 10))
        capture("guest-ad-earned-thread", app)
    }

    func testEmptyWalletOffersRechargeWithoutLosingComparison() {
        let app = launch(route: "fitlab-input", extra: ["--coordit-fitlab-fixture", "url-success", "--coordit-rewarded-ad-fixture", "credited", "--coordit-storekit-fixture", "credited", "--coordit-shared-fitlab-url", "https://shop.example/shirt"])
        tap("fitlab-url-import", app)
        tap("fitlab-show-comparison", app)
        tap("fitlab-choose-closet", app)
        tap("fitlab-reference-reference-fixture-shirt", app)
        tap("fitlab-reference-picker-done", app)
        tap("fitlab-submit-analysis", app)
        let alert = app.alerts["실타래가 부족해요"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        capture("empty-wallet-recharge-prompt", app)
        alert.buttons["나중에"].tap()
        XCTAssertTrue(element("fitlab-selected-reference-summary", app).exists)
        XCTAssertTrue(element("fitlab-submission-ledger", app).label.contains("recommend=0"))
        tap("fitlab-submit-analysis", app)
        alert.buttons["실타래 충전하기"].tap()
        XCTAssertTrue(element("coordit-screen-mypage-thread-charge", app).waitForExistence(timeout: 5))
        XCTAssertTrue(element("coordit-thread-charge-ad-cta", app).waitForExistence(timeout: 5))
        tap("coordit-thread-charge-ad-cta", app)
        XCTAssertTrue(app.staticTexts["1 실타래"].waitForExistence(timeout: 10))
        app.buttons["FIT LAB"].tap()
        XCTAssertTrue(element("fitlab-selected-reference-summary", app).waitForExistence(timeout: 5))
        tap("fitlab-submit-analysis", app)
        XCTAssertTrue(element("fitlab-size-score-M", app).waitForExistence(timeout: 10))
        XCTAssertEqual(element("coordit-thread-balance-probe", app).label, "0")
    }

    func testManualEntryAppearsOnlyAfterImportFailure() {
        let fitLab = launch(route: "fitlab-input", extra: ["--coordit-fitlab-fixture", "ocr-errors"])
        XCTAssertFalse(element("fitlab-source-manual", fitLab).exists)
        tap("fitlab-source-ocr", fitLab)
        XCTAssertFalse(element("fitlab-ocr-manual-fallback", fitLab).exists)
        tap("fitlab-ocr-simulate-unparseable", fitLab)
        tap("fitlab-ocr-manual-fallback", fitLab)
        XCTAssertTrue(element("fitlab-manual-form", fitLab).waitForExistence(timeout: 5))
        fitLab.terminate()

        let closet = launch(route: "closet-add-method", extra: ["--coordit-test-link-extraction-failure"])
        XCTAssertFalse(element("closet-add-method-manual", closet).exists)
        tap("closet-add-method-link", closet)
        XCTAssertFalse(closet.buttons["직접 입력하기"].exists)
        tap("closet-add-submit", closet)
        XCTAssertTrue(closet.buttons["직접 입력하기"].waitForExistence(timeout: 5))
        capture("closet-import-manual-recovery", closet)
        closet.buttons["직접 입력하기"].tap()
        XCTAssertTrue(element("coordit-screen-closet-add-manual", closet).waitForExistence(timeout: 5))
    }

    private func launch(route: String, authenticated: Bool = true, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--coordit-ui-testing", "--coordit-start-route", route, "--coordit-thread-balance", "0", "--coordit-monetization-readiness", "enabled"] + (authenticated ? ["--coordit-ui-testing-authenticated"] : []) + extra
        app.launch()
        return app
    }
    private func element(_ id: String, _ app: XCUIApplication) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
    private func tap(_ id: String, _ app: XCUIApplication) {
        let target = element(id, app)
        XCTAssertTrue(target.waitForExistence(timeout: 8), id)
        for _ in 0..<8 where !target.isHittable { app.swipeUp() }
        target.tap()
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
