#if canImport(XCTest)
import XCTest

final class CoorditFeatureFlowsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testSplashSignupEntryOpensAccountLogin() throws {
        let app = launchApp(at: "splash")
        assertScreen("splash", in: app)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "splash-signup-entry"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        let signupEntry = app.buttons["splash-signup-entry"]
        XCTAssertTrue(signupEntry.waitForExistence(timeout: 5), "Missing splash signup entry")
        XCTAssertEqual(signupEntry.label, "로그인/회원가입")
        signupEntry.tap()

        assertScreen("mypage-account", in: app)
        XCTAssertTrue(element("mypage-backend-email", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(element("mypage-backend-password", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["mypage-backend-login"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["mypage-backend-signup"].waitForExistence(timeout: 5))
    }

    func testDefaultLaunchShowsSplashSignupEntry() throws {
        let app = XCUIApplication()
        app.launch()

        assertScreen("splash", in: app)
        XCTAssertTrue(app.buttons["splash-signup-entry"].waitForExistence(timeout: 5))
    }

    func testSplashLogoIsHorizontallyCentered() throws {
        let app = launchApp(at: "splash")
        assertScreen("splash", in: app)

        let screenshot = app.screenshot().image
        let logoCenter = try whiteLogoCenter(in: screenshot)
        let screenCenter = CGFloat(screenshot.cgImage!.width) / 2

        XCTAssertEqual(logoCenter, screenCenter, accuracy: 6)
    }

    func testFitLabInputSourcesAndHistoryFlow() throws {
        var app = launchApp(at: "fitlab-input")
        assertScreen("fitlab-input", in: app)
        XCTAssertTrue(app.buttons["사이즈표 수동 입력"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["사이즈표 OCR 입력"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["상품 링크 입력"].waitForExistence(timeout: 5))
        app.terminate()

        let historyNamespace = "feature-flow-\(UUID().uuidString)"
        app = launchApp(
            at: "fitlab-result-bottom",
            fixture: "history-persistence",
            extraArguments: [
                "--coordit-fitlab-history-namespace", historyNamespace,
                "--coordit-fitlab-history-reset",
            ]
        )
        assertScreen("fitlab-result-bottom", in: app)
        let addToHistory = app.buttons["히스토리에 추가"]
        XCTAssertTrue(addToHistory.waitForExistence(timeout: 5))
        addToHistory.tap()
        XCTAssertTrue(element("fitlab-history-saved-confirmation", in: app).waitForExistence(timeout: 5))
        app.buttons["FIT LAB 뒤로가기"].tap()
        assertScreen("fitlab-input", in: app)
        let historyCard = element("fitlab-history-card-analysis-fixture-lower", in: app)
        XCTAssertTrue(historyCard.waitForExistence(timeout: 5))
        historyCard.tap()
        assertScreen("fitlab-history-detail", in: app)
        XCTAssertEqual(element("fitlab-history-detail-analysis", in: app).label, "analysis-fixture-lower")
    }

    func testMyPageRowsOpenTheirFinalScreens() throws {
        let destinations = [
            ("계정", "mypage-account"),
            ("내 신체 정보", "mypage-body"),
            ("알림", "mypage-notifications"),
            ("개인정보/보안", "mypage-privacy"),
            ("앱 설정", "mypage-app-settings"),
        ]

        for (label, route) in destinations {
            let app = launchApp(at: "mypage")
            assertScreen("mypage", in: app)
            let row = app.buttons[label]
            XCTAssertTrue(row.waitForExistence(timeout: 5), "Missing My Page row: \(label)")
            row.tap()
            assertScreen(route, in: app)
            app.terminate()
            XCTAssertTrue(app.wait(for: .notRunning, timeout: 5))
        }
    }

    func testClosetOverviewOpensWideDenimDetail() throws {
        let app = launchApp(at: "closet-overview")
        assertScreen("closet-overview", in: app)

        let wideDenim = app.buttons["Wide Denim"]
        XCTAssertTrue(wideDenim.waitForExistence(timeout: 5))
        wideDenim.tap()

        assertScreen("closet-detail-bottom", in: app)
        XCTAssertTrue(element("Wide Denim", in: app).waitForExistence(timeout: 5))
    }

    func testClosetAddInputsMatchRelocatedPhotoRequirements() throws {
        var app = launchApp(at: "closet-add-method")
        assertScreen("closet-add-method", in: app)

        app.terminate()
        app = launchApp(at: "closet-add-photo")
        XCTAssertTrue(element("closet-size-chart-photo", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(
            element("closet-garment-photo", in: app).exists,
            "Photo input must reserve garment photos for FIT DETAIL."
        )

        app.terminate()
        app = launchApp(at: "closet-add-manual")
        XCTAssertFalse(
            element("closet-manual-garment-photo", in: app).exists,
            "Manual input must reserve garment photos for FIT DETAIL."
        )
        for index in 0..<4 {
            XCTAssertTrue(
                app.textFields["closet-manual-measurement-\(index)"].waitForExistence(timeout: 5),
                "Manual input must retain measurement field \(index)."
            )
        }
    }

    func testClosetLinkAddShowsResultAndPersistsInOverview() throws {
        let app = launchApp(at: "closet-overview")
        assertScreen("closet-overview", in: app)

        app.buttons["closet-add-garment"].tap()
        app.buttons["closet-add-method-link"].tap()
        assertScreen("closet-add-link", in: app)

        let nameField = app.textFields["closet-garment-name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("New Shirt")

        let linkField = app.textFields["closet-product-link"]
        linkField.tap()
        linkField.typeText("https://coordit.test/item")
        app.swipeDown()

        let submit = app.buttons["closet-add-submit"]
        XCTAssertTrue(submit.isEnabled)
        submit.tap()
        assertScreen("closet-add-loading", in: app)
        assertScreen("closet-add-result", in: app)
        XCTAssertTrue(element("New Shirt", in: app).waitForExistence(timeout: 5))

        let backToCloset = app.buttons["FIT DETAIL"]
        XCTAssertTrue(backToCloset.waitForExistence(timeout: 5))
        backToCloset.tap()
        assertScreen("closet-overview", in: app)
        XCTAssertTrue(app.buttons["New Shirt"].waitForExistence(timeout: 5))
    }

    private func launchApp(
        at route: String,
        fixture: String? = nil,
        extraArguments: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--coordit-ui-testing",
            "--coordit-start-route",
            route,
        ]
        if let fixture {
            app.launchArguments += ["--coordit-fitlab-fixture", fixture]
        }
        app.launchArguments += extraArguments
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
            "Missing final route: \(route)",
            file: file,
            line: line
        )
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func whiteLogoCenter(in image: UIImage) throws -> CGFloat {
        let cgImage = try XCTUnwrap(image.cgImage)
        let width = cgImage.width
        let height = cgImage.height
        let context = try XCTUnwrap(
            CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        let bytes = try XCTUnwrap(context.data?.assumingMemoryBound(to: UInt8.self))
        let minY = Int(CGFloat(height) * 0.40)
        let maxY = Int(CGFloat(height) * 0.56)
        var minX = width
        var maxX = 0

        for y in minY..<maxY {
            let row = bytes + y * width * 4
            for x in 0..<width {
                let pixel = row + x * 4
                guard pixel[0] > 230, pixel[1] > 230, pixel[2] > 230 else { continue }
                minX = min(minX, x)
                maxX = max(maxX, x)
            }
        }

        XCTAssertLessThan(minX, maxX, "Could not locate the white splash logo")
        return CGFloat(minX + maxX) / 2
    }
}
#endif
