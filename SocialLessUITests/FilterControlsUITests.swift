import XCTest

final class FilterControlsUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch(reset: Bool = true, websitePilot: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"] + (reset ? ["--reset-test-data"] : [])
        if websitePilot { app.launchArguments.append("--instagram-filter-fixture") }
        app.launch()
        if reset {
            XCTAssertTrue(app.buttons["onboarding.skip"].waitForExistence(timeout: 10))
            app.buttons["onboarding.skip"].tap()
        }
        XCTAssertTrue(app.buttons["platform.instagram"].waitForExistence(timeout: 10))
        return app
    }
    @MainActor private func start(_ app: XCUIApplication, platform: String = "instagram", website: Bool = false) {
        app.buttons["platform.\(platform)"].tap()
        if website {
            let picker = app.buttons["session.mode"]
            for _ in 0..<5 where !picker.isHittable { app.swipeUp() }
            picker.tap()
            app.buttons["Website · experimental"].tap()
        }
        let start = app.buttons["session.start"]
        for _ in 0..<5 where !start.isHittable { app.swipeUp() }
        start.tap()
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 10))
    }
    @MainActor private func toggle(_ app: XCUIApplication, id: String, expected: String) {
        let control = app.switches[id]
        XCTAssertTrue(control.waitForExistence(timeout: 5))
        control.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        XCTAssertEqual(control.value as? String, expected)
    }
    @MainActor private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }
    @MainActor private func expectAbsent(_ element: XCUIElement) {
        let hidden = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element)
        wait(for: [hidden], timeout: 5)
    }

    @MainActor func testFiltersHideOnlySampleNavigationAndRestoreWithoutReload() {
        let app = launch()
        start(app)
        let discover = app.webViews.links["Sample Discover"].firstMatch
        let videos = app.webViews.links["Sample Short videos"].firstMatch
        XCTAssertTrue(discover.waitForExistence(timeout: 10))
        app.buttons["browser.filters"].tap()
        toggle(app, id: "filters.enabled", expected: "1")
        XCTAssertTrue(app.staticTexts["Filters active"].waitForExistence(timeout: 5))
        capture("09-Filter-Controls")
        app.buttons["filters.done"].tap()
        expectAbsent(discover); expectAbsent(videos)
        XCTAssertTrue(app.webViews.links["Sample friends"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["session.countdown"].exists)
        capture("10-Filtered-Demo")
        app.buttons["browser.filters"].tap()
        toggle(app, id: "filters.rule.demo-discovery", expected: "0")
        app.buttons["filters.done"].tap()
        XCTAssertTrue(discover.waitForExistence(timeout: 5)); expectAbsent(videos)
        app.buttons["browser.filters"].tap()
        toggle(app, id: "filters.enabled", expected: "0")
        app.buttons["filters.done"].tap()
        XCTAssertTrue(discover.waitForExistence(timeout: 5))
        XCTAssertTrue(videos.waitForExistence(timeout: 5))
        capture("11-Restored-Demo")
        app.buttons["session.close"].tap()
        XCTAssertTrue(app.staticTexts["session.completed"].waitForExistence(timeout: 5))
    }

    @MainActor func testFilterPreferencesPersistAndStaySeparateForEachPlatform() {
        let app = launch()
        app.tabBars.buttons["Settings"].tap()
        let preferences = app.buttons["settings.filters.instagram"]
        for _ in 0..<5 where !preferences.isHittable { app.swipeUp() }
        preferences.tap()
        toggle(app, id: "filters.enabled", expected: "1")
        app.terminate()
        let reopened = launch(reset: false)
        start(reopened)
        XCTAssertTrue(reopened.webViews.links["Sample friends"].firstMatch.waitForExistence(timeout: 10))
        expectAbsent(reopened.webViews.links["Sample Discover"].firstMatch)
        reopened.buttons["session.close"].tap()
        XCTAssertTrue(reopened.buttons["session.done"].waitForExistence(timeout: 5))
        reopened.buttons["session.done"].tap()
        start(reopened, platform: "facebook")
        XCTAssertTrue(reopened.webViews.links["Sample Discover"].firstMatch.waitForExistence(timeout: 10))
        reopened.buttons["browser.filters"].tap()
        XCTAssertEqual(reopened.switches["filters.enabled"].value as? String, "0")
    }

    @MainActor func testInstagramPilotChecksBeforeHidingAndResetsForNewSession() {
        let app = launch(websitePilot: true)
        start(app, website: true)
        let reels = app.webViews.links["Sample Reels"].firstMatch
        XCTAssertTrue(reels.waitForExistence(timeout: 10))
        app.buttons["browser.filters"].tap()
        XCTAssertFalse(app.switches["filters.enabled"].isEnabled)
        capture("12-Instagram-Pilot-Check")
        app.buttons["filters.checkPage"].tap()
        XCTAssertTrue(app.staticTexts["Compatible navigation link found"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.switches["filters.enabled"].value as? String, "0")
        app.buttons["filters.done"].tap()
        XCTAssertTrue(reels.waitForExistence(timeout: 5), "The check itself must not hide a link")
        app.buttons["browser.filters"].tap()
        toggle(app, id: "filters.enabled", expected: "1")
        XCTAssertTrue(app.staticTexts["Filters active"].waitForExistence(timeout: 5))
        capture("13-Instagram-Pilot-Enabled")
        app.buttons["filters.done"].tap()
        expectAbsent(reels)
        XCTAssertTrue(app.webViews.links["Sample Messages"].firstMatch.exists)
        XCTAssertTrue(app.webViews.links["Sample Stories"].firstMatch.exists)
        XCTAssertTrue(app.webViews.staticTexts["This sample post stays visible."].firstMatch.exists)
        app.buttons["browser.filters"].tap()
        toggle(app, id: "filters.enabled", expected: "0")
        app.buttons["filters.done"].tap()
        XCTAssertTrue(reels.waitForExistence(timeout: 5))
        app.buttons["browser.filters"].tap()
        toggle(app, id: "filters.enabled", expected: "1")
        app.buttons["filters.done"].tap()
        app.buttons["session.close"].tap()
        XCTAssertTrue(app.buttons["session.done"].waitForExistence(timeout: 5))
        app.buttons["session.done"].tap()
        start(app, website: true)
        XCTAssertTrue(reels.waitForExistence(timeout: 10))
        app.buttons["browser.filters"].tap()
        XCTAssertFalse(app.switches["filters.enabled"].isEnabled)
        XCTAssertEqual(app.switches["filters.enabled"].value as? String, "0")
        XCTAssertTrue(app.buttons["filters.checkPage"].exists)
    }

    @MainActor func testRememberedInstagramChoiceSurvivesRelaunchAndCanBeForgotten() {
        let app = launch(websitePilot: true)
        start(app, website: true)
        XCTAssertTrue(app.webViews.links["Sample Reels"].firstMatch.waitForExistence(timeout: 10))
        app.buttons["browser.filters"].tap()
        app.buttons["filters.checkPage"].tap()
        XCTAssertTrue(app.staticTexts["Compatible navigation link found"].waitForExistence(timeout: 5))
        toggle(app, id: "filters.enabled", expected: "1")
        XCTAssertTrue(app.staticTexts["Filters active"].waitForExistence(timeout: 5))
        let remember = app.switches["filters.remember"]
        for _ in 0..<5 where !remember.isHittable { app.swipeUp() }
        toggle(app, id: "filters.remember", expected: "1")
        capture("14-Remember-Instagram-Filters")
        app.buttons["filters.done"].tap()
        app.buttons["session.close"].tap()
        XCTAssertTrue(app.buttons["session.done"].waitForExistence(timeout: 5))
        app.buttons["session.done"].tap()
        app.terminate()

        let reopened = launch(reset: false, websitePilot: true)
        start(reopened, website: true)
        XCTAssertTrue(reopened.webViews.links["Sample Messages"].firstMatch.waitForExistence(timeout: 10))
        expectAbsent(reopened.webViews.links["Sample Reels"].firstMatch)
        reopened.buttons["browser.filters"].tap()
        XCTAssertTrue(reopened.staticTexts["Filters active"].waitForExistence(timeout: 5))
        toggle(reopened, id: "filters.enabled", expected: "0")
        reopened.buttons["filters.done"].tap()
        XCTAssertTrue(reopened.webViews.links["Sample Reels"].firstMatch.waitForExistence(timeout: 5))
        reopened.buttons["session.close"].tap()
        XCTAssertTrue(reopened.buttons["session.done"].waitForExistence(timeout: 5))
        reopened.buttons["session.done"].tap()
        reopened.terminate()

        let off = launch(reset: false, websitePilot: true)
        start(off, website: true)
        XCTAssertTrue(off.webViews.links["Sample Reels"].firstMatch.waitForExistence(timeout: 10))
        off.buttons["browser.filters"].tap()
        XCTAssertEqual(off.switches["filters.enabled"].value as? String, "0")
        toggle(off, id: "filters.enabled", expected: "1")
        XCTAssertTrue(off.staticTexts["Filters active"].waitForExistence(timeout: 5))
        let saved = off.switches["filters.remember"]
        for _ in 0..<5 where !saved.isHittable { off.swipeUp() }
        toggle(off, id: "filters.remember", expected: "0")
        off.buttons["filters.done"].tap()
        expectAbsent(off.webViews.links["Sample Reels"].firstMatch)
        off.buttons["session.close"].tap()
        XCTAssertTrue(off.buttons["session.done"].waitForExistence(timeout: 5))
        off.buttons["session.done"].tap()
        start(off, website: true)
        XCTAssertTrue(off.webViews.links["Sample Reels"].firstMatch.waitForExistence(timeout: 10))
        off.buttons["browser.filters"].tap()
        XCTAssertFalse(off.switches["filters.enabled"].isEnabled)
    }

    @MainActor func testExploreChecksSeparatelyAndRestoresWithoutDisablingReels() {
        let app = launch(websitePilot: true)
        start(app, website: true)
        XCTAssertTrue(app.webViews.links["Sample Explore"].firstMatch.waitForExistence(timeout: 10))
        app.buttons["browser.filters"].tap()
        app.buttons["filters.checkPage"].tap()
        XCTAssertTrue(app.staticTexts["Compatible navigation link found"].waitForExistence(timeout: 5))
        toggle(app, id: "filters.enabled", expected: "1")
        XCTAssertTrue(app.staticTexts["Filters active"].waitForExistence(timeout: 5))
        let exploreSwitch = app.switches["filters.rule.instagram-explore-navigation"]
        for _ in 0..<6 where !exploreSwitch.isHittable { app.swipeUp() }
        XCTAssertFalse(exploreSwitch.isEnabled)
        let check = app.buttons["filters.check.instagram-explore-navigation"]
        for _ in 0..<6 where !check.isHittable { app.swipeUp() }
        check.tap()
        let ready = expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: exploreSwitch)
        wait(for: [ready], timeout: 5)
        app.buttons["filters.done"].tap()
        XCTAssertTrue(app.webViews.links["Sample Explore"].firstMatch.exists)
        expectAbsent(app.webViews.links["Sample Reels"].firstMatch)
        app.buttons["browser.filters"].tap()
        for _ in 0..<6 where !exploreSwitch.isHittable { app.swipeUp() }
        toggle(app, id: "filters.rule.instagram-explore-navigation", expected: "1")
        capture("15-Explore-Filter")
        app.buttons["filters.done"].tap()
        expectAbsent(app.webViews.links["Sample Explore"].firstMatch)
        expectAbsent(app.webViews.links["Sample Reels"].firstMatch)
        XCTAssertTrue(app.webViews.links["Sample Search"].firstMatch.exists)
        XCTAssertTrue(app.webViews.links["Sample Messages"].firstMatch.exists)
        app.buttons["browser.filters"].tap()
        for _ in 0..<6 where !exploreSwitch.isHittable { app.swipeUp() }
        toggle(app, id: "filters.rule.instagram-explore-navigation", expected: "0")
        app.buttons["filters.done"].tap()
        XCTAssertTrue(app.webViews.links["Sample Explore"].firstMatch.waitForExistence(timeout: 5))
        expectAbsent(app.webViews.links["Sample Reels"].firstMatch)
    }
    @MainActor func testFollowingImportPreviewPersistenceFilteringAndDelete() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-test-data", "--instagram-filter-fixture", "--following-import-fixture"]
        app.launch()
        XCTAssertTrue(app.buttons["onboarding.skip"].waitForExistence(timeout: 10))
        app.buttons["onboarding.skip"].tap()
        app.tabBars.buttons["Settings"].tap()
        let importLink = app.buttons["settings.following"]
        for _ in 0..<6 where !importLink.isHittable { app.swipeUp() }
        importLink.tap()
        let fixture = app.buttons["following.fixture"]
        for _ in 0..<6 where !fixture.isHittable { app.swipeUp() }
        fixture.tap()
        let save = app.buttons["following.save"]
        for _ in 0..<6 where !save.isHittable { app.swipeUp() }
        XCTAssertTrue(save.exists); save.tap()
        app.terminate()
        let reopened = launch(reset: false, websitePilot: true)
        start(reopened, website: true)
        XCTAssertTrue(reopened.webViews.links["sample_other"].firstMatch.waitForExistence(timeout: 5))
        reopened.buttons["browser.filters"].tap()
        let storiesToggle = reopened.switches["filters.storiesEnabled"]
        for _ in 0..<10 where !storiesToggle.isHittable || storiesToggle.frame.maxY > reopened.frame.maxY - 100 { reopened.swipeUp() }
        XCTAssertEqual(storiesToggle.value as? String, "0")
        storiesToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        let storiesOn = expectation(for: NSPredicate(format: "value == %@", "1"), evaluatedWith: storiesToggle)
        wait(for: [storiesOn], timeout: 5)
        XCTAssertTrue(reopened.staticTexts["Filter applies to the stories viewer only"].waitForExistence(timeout: 5))
        capture("17-Stories-Filter-Controls")
        storiesToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        let storiesOff = expectation(for: NSPredicate(format: "value == %@", "0"), evaluatedWith: storiesToggle)
        wait(for: [storiesOff], timeout: 5)
        let toggleID = "filters.followingEnabled"
        let feedToggle = reopened.switches[toggleID]
        for _ in 0..<10 where !feedToggle.isHittable { reopened.swipeUp() }
        XCTAssertEqual(feedToggle.value as? String, "0")
        toggle(reopened, id: toggleID, expected: "1")
        XCTAssertTrue(reopened.staticTexts["Imported-account filter active"].waitForExistence(timeout: 5))
        capture("16-Following-Feed-Filter")
        reopened.buttons["filters.done"].tap()
        expectAbsent(reopened.webViews.links["sample_other"].firstMatch)
        XCTAssertTrue(reopened.webViews.links["sample_friend"].firstMatch.exists)
        reopened.buttons["browser.filters"].tap()
        let manage = reopened.buttons["filters.followingList"]
        for _ in 0..<10 where !manage.isHittable { reopened.swipeUp() }
        manage.tap()
        let delete = reopened.buttons["following.delete"]
        for _ in 0..<8 where !delete.isHittable { reopened.swipeUp() }
        delete.tap(); reopened.buttons["Delete list"].tap()
        reopened.navigationBars["Following list"].buttons.element(boundBy: 0).tap()
        for _ in 0..<10 where !feedToggle.isHittable { reopened.swipeUp() }
        XCTAssertEqual(feedToggle.value as? String, "0"); XCTAssertFalse(feedToggle.isEnabled)
        reopened.buttons["filters.done"].tap()
        XCTAssertTrue(reopened.webViews.links["sample_other"].firstMatch.waitForExistence(timeout: 5))
        reopened.buttons["session.close"].tap()
        XCTAssertTrue(reopened.staticTexts["session.completed"].waitForExistence(timeout: 5))
    }

}
