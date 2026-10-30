import XCTest
import UIKit

final class CoorditReleaseLinkFlowUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testLinkSummaryIsFreeAndComparisonChargesOnlyAfterExplicitSubmit() {
        let app = launch(balance: 1)
        tap("fitlab-source-url", app)
        XCTAssertTrue(element("fitlab-url-paste", app).exists)
        UIPasteboard.general.setItems([[UIPasteboard.typeAutomatic: "https://shop.example/products/linen-shirt"]], options: [.localOnly: true])
        tap("fitlab-url-paste", app)
        XCTAssertEqual(element("fitlab-url-field", app).value as? String, "https://shop.example/products/linen-shirt")
        capture("release-fitlab-paste", app)

        tap("fitlab-url-import", app)

        XCTAssertTrue(element("fitlab-free-summary", app).waitForExistence(timeout: 5))
        XCTAssertEqual(element("coordit-thread-balance-probe", app).label, "1")
        XCTAssertFalse(element("fitlab-submit-analysis", app).exists)
        assertNoAnalysis(app)
        XCTAssertFalse(element("fitlab-summary-highlight", app).exists)
        XCTAssertTrue(element("fitlab-summary-size-reading", app).label.contains("+2cm"))
        XCTAssertTrue(element("fitlab-summary-analysis", app).exists)
        XCTAssertTrue(element("fitlab-summary-evidence", app).exists)
        capture("release-free-summary", app)
        scrollToComparison(app)
        capture("release-free-summary-end", app)
        app.swipeDown()
        tap("fitlab-toggle-measurements", app)
        tap("fitlab-product-size-L", app)
        XCTAssertTrue(element("fitlab-summary-size-difference", app).label.contains("L → M"))
        scrollToComparison(app)
        capture("release-expanded-summary-end", app)
        tap("fitlab-show-comparison", app)
        XCTAssertTrue(element("fitlab-manage-references", app).waitForExistence(timeout: 5))
        XCTAssertTrue(element("fitlab-camera-comparison", app).isEnabled)
        tap("fitlab-camera-comparison", app)
        let cameraNotice = app.alerts["카메라 측정 기능은 준비 중입니다!"]
        XCTAssertTrue(cameraNotice.waitForExistence(timeout: 3))
        capture("release-camera-coming-soon", app)
        cameraNotice.buttons["확인"].tap()
        XCTAssertFalse(cameraNotice.exists)
        XCTAssertEqual(element("coordit-thread-balance-probe", app).label, "1")
        app.buttons["FIT LAB 뒤로가기"].tap()
        XCTAssertTrue(element("fitlab-free-summary", app).waitForExistence(timeout: 5))
        assertNoAnalysis(app)
        tap("fitlab-show-comparison", app)
        XCTAssertFalse(element("fitlab-submit-analysis", app).isEnabled)
        assertNoAnalysis(app)
        XCTAssertFalse(element("fitlab-reference-reference-fixture-shirt", app).exists)
        tap("fitlab-choose-closet", app)
        capture("closet-reference-picker", app)
        tap("fitlab-reference-reference-fixture-shirt", app)
        tap("fitlab-reference-picker-close", app)
        XCTAssertFalse(element("fitlab-selected-reference-summary", app).exists)
        XCTAssertFalse(element("fitlab-submit-analysis", app).isEnabled)
        tap("fitlab-choose-closet", app)
        XCTAssertEqual(element("fitlab-reference-reference-fixture-shirt", app).value as? String, "선택 안 됨")
        tap("fitlab-reference-reference-fixture-shirt", app)
        tap("fitlab-reference-picker-done", app)
        XCTAssertTrue(element("fitlab-selected-reference-summary", app).exists)
        XCTAssertEqual(element("coordit-thread-balance-probe", app).label, "1")
        capture("release-comparison-ready", app)
        tap("fitlab-submit-analysis", app)
        XCTAssertTrue(element("fitlab-size-score-M", app).waitForExistence(timeout: 15))
        XCTAssertEqual(element("coordit-thread-balance-probe", app).label, "0")
        let ledger = element("fitlab-submission-ledger", app).label
        XCTAssertTrue(ledger.contains("recommend=1"), ledger)
        XCTAssertTrue(ledger.contains("report=1"), ledger)
        capture("release-paid-result", app)
    }

    func testManualReportDoesNotInventSellerFacts() {
        let app = launch(balance: 0, fixture: "url-manual-report")
        XCTAssertTrue(element("fitlab-free-summary", app).waitForExistence(timeout: 5))
        XCTAssertTrue(element("fitlab-summary-facts-unavailable", app).exists)
        XCTAssertFalse(element("fitlab-summary-source", app).exists)
        capture("report-manual", app)
        assertNoAnalysis(app)
    }

    func testEditingImportedProductNameHidesOriginalSellerFacts() {
        let app = launch(balance: 0, extra: ["--coordit-shared-fitlab-url", "https://shop.example/products/linen-shirt"])
        tap("fitlab-url-import", app)
        XCTAssertTrue(element("fitlab-summary-evidence", app).waitForExistence(timeout: 5))
        scrollToComparison(app)
        tap("fitlab-edit-product", app)
        let field = element("fitlab-product-name", app)
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        let current = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + "수정 상품")
        if app.buttons["완료"].exists { app.buttons["완료"].tap() }
        tap("fitlab-manual-continue", app)
        tap("fitlab-manual-confirm", app)
        XCTAssertTrue(element("fitlab-free-summary", app).waitForExistence(timeout: 5))
        XCTAssertFalse(element("fitlab-summary-evidence", app).exists)
        XCTAssertTrue(element("fitlab-summary-facts-unavailable", app).exists)
        capture("report-edited-identity", app)
        assertNoAnalysis(app)
    }

    func testMissingProductFactsStillShowsFreeSizeReport() {
        let app = launch(balance: 0, extra: ["--coordit-shared-fitlab-url", "https://shop.example/products/facts-missing"])
        tap("fitlab-url-import", app)
        XCTAssertTrue(element("fitlab-free-summary", app).waitForExistence(timeout: 5))
        XCTAssertTrue(element("fitlab-summary-facts-unavailable", app).exists)
        XCTAssertFalse(element("fitlab-summary-evidence", app).exists)
        capture("report-missing-facts", app)
        scrollToComparison(app)
        capture("report-missing-facts-end", app)
        assertNoAnalysis(app)
    }

    func testZeroThreadsStillAllowsFreeSummaryAndReferenceRegistration() {
        let app = launch(balance: 0, extra: ["--coordit-shared-fitlab-url", "https://shop.example/product"])

        tap("fitlab-url-import", app)

        XCTAssertTrue(element("fitlab-free-summary", app).waitForExistence(timeout: 5))
        XCTAssertEqual(element("coordit-thread-balance-probe", app).label, "0")
        assertNoAnalysis(app)
        tap("fitlab-show-comparison", app)
        tap("fitlab-manage-references", app)
        XCTAssertTrue(element("closet-product-link", app).waitForExistence(timeout: 5))
        XCTAssertTrue(element("closet-link-paste", app).exists)
        capture("release-register-reference-link", app)
    }

    func testClosetPasteInsertsClipboardURL() {
        let app = launch(route: "closet-add-link", balance: 0)

        UIPasteboard.general.setItems([[UIPasteboard.typeAutomatic: "https://shop.example/products/my-shirt"]], options: [.localOnly: true])
        tap("closet-link-paste", app)

        let field = element("closet-product-link", app)
        XCTAssertTrue(NSPredicate(format: "value == %@", "https://shop.example/products/my-shirt")
            .evaluate(with: field))
        capture("release-closet-paste", app)
    }

    func testCameraRouteIsUnavailableAndMainMagazineUsesMainDesign() {
        let app = launch(route: "closet-add-photo", balance: 0)

        XCTAssertTrue(element("closet-add-method-link", app).waitForExistence(timeout: 5))
        XCTAssertTrue(element("closet-add-method-photo", app).isEnabled)
        tap("closet-add-method-photo", app)
        let cameraNotice = app.alerts["카메라 측정 기능은 준비 중입니다!"]
        XCTAssertTrue(cameraNotice.waitForExistence(timeout: 3))
        capture("release-closet-camera-coming-soon", app)
        cameraNotice.buttons["확인"].tap()
        XCTAssertFalse(cameraNotice.exists)
        XCTAssertTrue(element("coordit-screen-closet-add-method", app).exists)
        tap("closet-add-method-link", app)
        XCTAssertTrue(element("closet-product-link", app).waitForExistence(timeout: 5))
        capture("release-camera-route-blocked", app)
        app.terminate()
        let home = launch(route: "main04", balance: 0)
        XCTAssertTrue(element("coordit-main04-banner", home).waitForExistence(timeout: 5))
        XCTAssertTrue(home.staticTexts["COORDIT MAGAZINE"].exists)
        capture("release-main-magazine", home)
    }

    func testSharedNavigationAcrossTabsAndFitLabInputSteps() {
        let app = launch(route: "main04", balance: 1)
        XCTAssertTrue(app.buttons["FIT LAB"].waitForExistence(timeout: 5))
        app.buttons["FIT LAB"].tap()
        XCTAssertTrue(element("fitlab-source-url", app).waitForExistence(timeout: 5))
        XCTAssertFalse(element("fitlab-source-manual", app).exists)
        for source in ["url", "ocr"] {
            tap("fitlab-source-\(source)", app)
            XCTAssertTrue(app.buttons["FIT LAB 뒤로가기"].exists)
            capture("release-navigation-\(source)", app)
            app.buttons["FIT LAB 뒤로가기"].tap()
            XCTAssertTrue(element("fitlab-source-url", app).waitForExistence(timeout: 5))
        }
        app.buttons["CLOSET"].tap()
        tap("closet-add-garment", app)
        tap("closet-add-method-link", app)
        XCTAssertTrue(element("closet-product-link", app).waitForExistence(timeout: 5))
        app.buttons["HOME"].tap()
        XCTAssertTrue(element("coordit-main04-banner", app).waitForExistence(timeout: 5))
        XCTAssertTrue(element("coordit-shared-app-background", app).exists)
    }

    private func launch(route: String = "fitlab-input", balance: Int, fixture: String = "url-success", extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--coordit-ui-testing", "--coordit-ui-testing-authenticated",
            "--coordit-start-route", route, "--coordit-thread-balance", String(balance),
            "--coordit-fitlab-fixture", fixture] + extra
        app.launch()
        return app
    }

    private func scrollToComparison(_ app: XCUIApplication) {
        let compare = element("fitlab-show-comparison", app)
        for _ in 0..<12 {
            if compare.isHittable && compare.frame.maxY < app.frame.maxY - 110 { break }
            app.swipeUp()
        }
        XCTAssertTrue(compare.isHittable)
        let edit = element("fitlab-edit-product", app)
        XCTAssertTrue(edit.isHittable)
        XCTAssertLessThan(edit.frame.maxY, compare.frame.minY)
    }

    private func assertNoAnalysis(_ app: XCUIApplication) {
        let ledger = element("fitlab-submission-ledger", app).label
        XCTAssertTrue(ledger.contains("product=0"), ledger)
        XCTAssertTrue(ledger.contains("recommend=0"), ledger)
        XCTAssertTrue(ledger.contains("report=0"), ledger)
    }

    private func element(_ id: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func tap(_ id: String, _ app: XCUIApplication) {
        let target = element(id, app)
        XCTAssertTrue(target.waitForExistence(timeout: 5), id)
        for _ in 0..<8 where !target.isHittable { app.swipeUp() }
        XCTAssertTrue(target.isHittable, id)
        target.tap()
    }

    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
