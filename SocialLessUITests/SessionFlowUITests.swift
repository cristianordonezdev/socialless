import XCTest

final class SessionFlowUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch(fast: Bool = false, reset: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        if reset { app.launchArguments.append("--reset-test-data") }
        if fast { app.launchArguments.append("--fast-session") }
        app.launch()
        return app
    }
    @MainActor private func skipOnboarding(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["onboarding.skip"].waitForExistence(timeout: 10))
        app.buttons["onboarding.skip"].tap()
        XCTAssertTrue(app.buttons["platform.instagram"].waitForExistence(timeout: 5))
    }
    @MainActor private func start(_ app: XCUIApplication, platform: String = "instagram") {
        app.buttons["platform.\(platform)"].tap()
        let button = app.buttons["session.start"]
        if !button.isHittable { app.swipeUp() }
        XCTAssertTrue(button.waitForExistence(timeout: 5)); button.tap()
    }
    @MainActor private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor func testOnboardingToDashboardWithoutPermissions() {
        let app = launch()
        let next = app.buttons["onboarding.continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        capture("01-Onboarding")
        next.tap()
        if !next.isHittable { app.swipeUp() }
        next.tap()
        if !next.isHittable { app.swipeUp() }
        next.tap()
        XCTAssertTrue(app.buttons["platform.instagram"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["platform.facebook"].exists)
        capture("02-Dashboard")
    }

    @MainActor func testDemoExpirationRemovesBrowserAndRecordsOneSession() {
        let app = launch(fast: true)
        skipOnboarding(app); start(app)
        XCTAssertTrue(app.staticTexts["session.completed"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.webViews.firstMatch.exists)
        capture("04-Completion")
        app.buttons["session.done"].tap()
        app.tabBars.buttons["Insights"].tap()
        XCTAssertTrue(app.staticTexts["1 intentional sessions"].waitForExistence(timeout: 5))
    }

    @MainActor func testLocalFixtureAndIntentionalEarlyClose() {
        let app = launch()
        skipOnboarding(app); start(app)
        XCTAssertTrue(app.staticTexts["session.countdown"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.webViews.staticTexts["A small window"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.webViews.staticTexts["This is a fictional demo. No real profiles, posts, messages or account connection."].firstMatch.exists)
        capture("03-Offline-Browser")
        app.buttons["session.close"].tap()
        XCTAssertTrue(app.staticTexts["session.completed"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Ended intentionally"].exists)
        XCTAssertFalse(app.webViews.firstMatch.exists)
        app.buttons["session.done"].tap()
        XCTAssertTrue(app.buttons["platform.instagram"].waitForExistence(timeout: 5))
    }

    @MainActor func testCancelSetupDoesNotRecordSession() {
        let app = launch()
        skipOnboarding(app)
        app.buttons["platform.instagram"].tap()
        app.buttons["session.cancel"].tap()
        app.tabBars.buttons["Insights"].tap()
        XCTAssertTrue(app.staticTexts["0 intentional sessions"].waitForExistence(timeout: 5))
    }

    @MainActor func testSettingsPersistAcrossLaunch() {
        let app = launch()
        skipOnboarding(app)
        app.tabBars.buttons["Settings"].tap()
        let toggle = app.switches["settings.enabled.instagram"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        // SwiftUI exposes the full Form row as a switch; hit the actual trailing control.
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        XCTAssertEqual(toggle.value as? String, "0")
        capture("05-Settings")
        app.terminate()
        let reopened = launch(reset: false)
        XCTAssertTrue(reopened.buttons["platform.facebook"].waitForExistence(timeout: 10))
        XCTAssertFalse(reopened.buttons["platform.instagram"].exists)
        XCTAssertFalse(reopened.buttons["onboarding.skip"].exists)
    }

    @MainActor func testBackgroundPausesAndResumesCountdown() {
        let app = launch()
        skipOnboarding(app); start(app)
        let timer = app.staticTexts["session.countdown"]
        XCTAssertTrue(timer.waitForExistence(timeout: 5))
        let before = remaining(timer)
        XCUIDevice.shared.press(.home)
        // XCTest waits on a predicate instead of tying app logic to a test-only lifecycle path.
        let resumeAt = Date().addingTimeInterval(5)
        let delay = expectation(for: NSPredicate { _, _ in Date() >= resumeAt }, evaluatedWith: nil)
        wait(for: [delay], timeout: 7)
        app.activate()
        XCTAssertTrue(timer.waitForExistence(timeout: 5))
        XCTAssertLessThanOrEqual(before - remaining(timer), 3, "Five background seconds must not count")
        XCTAssertFalse(app.staticTexts["session.completed"].exists)
        app.buttons["session.close"].tap()
    }
    @MainActor private func remaining(_ element: XCUIElement) -> Int {
        let text = element.value as? String ?? element.label
        let parts = text.split(separator: ":").compactMap { Int($0) }
        XCTAssertEqual(parts.count, 2)
        return parts.count == 2 ? parts[0] * 60 + parts[1] : 0
    }

    @MainActor func testLargeTextAndLandscapeActionsRemainReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-test-data", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        skipOnboarding(app)
        capture("06-Large-Text-Dashboard")
        app.buttons["platform.instagram"].tap()
        let start = app.buttons["session.start"]
        for _ in 0..<8 where !start.isHittable { app.swipeUp() }
        XCTAssertTrue(start.isHittable)
        capture("07-Large-Text-Setup")
        app.buttons["session.cancel"].tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        XCTAssertTrue(app.buttons["platform.instagram"].exists)
        capture("08-Landscape")
    }
}

