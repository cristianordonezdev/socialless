import XCTest
@testable import SocialLess

final class FilterRuleTests: XCTestCase {
    private func sample() throws -> [String: Any] {
        let set = try FilterRuleRegistry().rules(for: .instagram, mode: .demo)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(set)) as? [String: Any])
    }

    private func decode(_ value: [String: Any], platform: SocialPlatform = .instagram, mode: BrowsingMode = .demo) throws -> FilterRuleSet {
        try FilterRuleRegistry.decode(JSONSerialization.data(withJSONObject: value), platform: platform, mode: mode)
    }

    func testBundledCatalogsSeparateDemoAndGatedInstagramPilot() throws {
        for platform in SocialPlatform.allCases {
            let demo = try FilterRuleRegistry().rules(for: platform, mode: .demo)
            XCTAssertTrue(demo.isAvailable)
            XCTAssertEqual(demo.platform, platform)
            XCTAssertEqual(demo.availability, .experimental)
            XCTAssertEqual(demo.rules.count, 2)
            XCTAssertTrue(demo.rules.allSatisfy { $0.pathPrefix.hasPrefix("/socialless-demo/") })
            let website = try FilterRuleRegistry().rules(for: platform, mode: .website)
            if platform == .instagram {
                XCTAssertTrue(website.isAvailable)
                XCTAssertTrue(website.requiresPageCheck)
                XCTAssertEqual(website.availability, .experimental)
                XCTAssertEqual(website.rules.count, 2)
                XCTAssertFalse(website.rules[1].enabledByDefault)
                XCTAssertEqual(website.rules[1].kind, .hideInstagramExploreNavigation)
                XCTAssertEqual(website.rules.first?.kind, .hideInstagramReelsNavigation)
                XCTAssertEqual(website.rules.first?.pathPrefix, "/reels")
            } else {
                XCTAssertFalse(website.isAvailable)
                XCTAssertTrue(website.rules.isEmpty)
                XCTAssertEqual(website.availability, .unavailable)
            }
        }
    }

    func testUnknownSchemaKindMalformedAndMismatchedScopeAreRejected() throws {
        var value = try sample()
        value["schemaVersion"] = 2
        XCTAssertThrowsError(try decode(value))
        value = try sample(); value["ruleSetVersion"] = "latest"
        XCTAssertThrowsError(try decode(value))
        value = try sample()
        var rules = try XCTUnwrap(value["rules"] as? [[String: Any]])
        rules[0]["kind"] = "evaluateScript"; value["rules"] = rules
        XCTAssertThrowsError(try decode(value))
        XCTAssertThrowsError(try decode(sample(), platform: .facebook))
        XCTAssertThrowsError(try decode(sample(), mode: .website))
        XCTAssertThrowsError(try FilterRuleRegistry.decode(Data("{}".utf8), platform: .instagram, mode: .demo))
    }

    func testDuplicateIDsUnavailableNonemptyAndInvalidIDsAreRejected() throws {
        var value = try sample()
        var rules = try XCTUnwrap(value["rules"] as? [[String: Any]])
        rules[1]["id"] = rules[0]["id"]; value["rules"] = rules
        XCTAssertThrowsError(try decode(value))
        value = try sample(); value["availability"] = "unavailable"
        XCTAssertThrowsError(try decode(value))
        value = try sample(); rules[0]["id"] = "unsafe'\"id"; value["rules"] = rules
        XCTAssertThrowsError(try decode(value))
    }

    func testPathNormalizationAndProtectedRoutes() throws {
        XCTAssertEqual(try FilterRuleRegistry.normalizePath("/sample/discover/"), "/sample/discover")
        XCTAssertEqual(try FilterRuleRegistry.normalizePath("/sample/discover"), "/sample/discover")
        for path in ["/", "//discover", "discover", "/../discover", "/discover//all", "/discover?x=1",
                     "/discover#one", "/%2Fdiscover", "https://example.com/discover", "/discover/../login",
                     "/login", "/accounts/login", "/discover/consent", "/AUTH", "/sign-in/", "/discover\\login"] {
            XCTAssertThrowsError(try FilterRuleRegistry.normalizePath(path), path)
        }
    }

    func testReelsAccessibilityFallbackIsRestrictedToInstagramWebsiteExactDestination() throws {
        let set = try FilterRuleRegistry().rules(for: .instagram, mode: .website)
        let original = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(set)) as? [String: Any])
        for platform in [SocialPlatform.facebook, .tiktok] {
            var value = original; value["platform"] = platform.rawValue
            XCTAssertThrowsError(try decode(value, platform: platform, mode: .website))
        }
        var value = original; value["scope"] = "demo"
        XCTAssertThrowsError(try decode(value))
        for path in ["/reel", "/reels/sample", "/explore"] {
            value = original
            var rules = try XCTUnwrap(value["rules"] as? [[String: Any]])
            rules[0]["pathPrefix"] = path; value["rules"] = rules
            XCTAssertThrowsError(try decode(value, mode: .website))
        }
    }

    @MainActor func testExistingPreferencesMigrateWithoutResettingUserChoices() throws {
        var old = AppSettings()
        old.completedOnboarding = true; old.keepHistory = false
        old.defaultMode = .website; old.enabledPlatforms = [.facebook]; old.defaultMinutes[.facebook] = 20
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as? [String: Any])
        json.removeValue(forKey: "filterPreferences")
        let restored = try JSONDecoder().decode(AppSettings.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(restored, old)
        XCTAssertFalse(restored.filters(for: .facebook, mode: .demo).enabled)
        let settings = MemorySettingsRepository()
        settings.value = restored
        let container = try AppContainer(repository: MemoryRepository(), settingsRepository: settings, time: FakeTime())
        container.settings.setFilters(FilterPreferences(enabled: true, ruleOverrides: ["demo-discovery": false]), for: .facebook, mode: .demo)
        let reopened = try AppContainer(repository: MemoryRepository(), settingsRepository: settings, time: FakeTime())
        XCTAssertTrue(reopened.settings.filters(for: .facebook, mode: .demo).enabled)
        XCTAssertFalse(reopened.settings.filters(for: .facebook, mode: .website).enabled)
        XCTAssertFalse(reopened.settings.filters(for: .instagram, mode: .demo).enabled)
        XCTAssertEqual(reopened.settings.enabledPlatforms, [.facebook])
        XCTAssertEqual(reopened.settings.minutes(for: .facebook), 20)
        XCTAssertFalse(reopened.settings.keepHistory)
    }

    func testOldPreferencesDoNotAcquireRememberedConsentAndVersionChangesResetSession() throws {
        let oldJSON = Data(#"{"enabled":true,"ruleOverrides":{"demo-discovery":false}}"#.utf8)
        let old = try JSONDecoder().decode(FilterPreferences.self, from: oldJSON)
        XCTAssertTrue(old.enabled)
        XCTAssertEqual(old.ruleOverrides["demo-discovery"], false)
        XCTAssertNil(old.rememberedRuleSetVersion)
        XCTAssertNil(old.approvedRuleIDs)
        let rules = try FilterRuleRegistry().rules(for: .instagram, mode: .website)
        XCTAssertEqual(old.forNewWebsiteSession(ruleSet: rules), FilterPreferences())
        let stale = FilterPreferences(enabled: true, rememberedRuleSetVersion: "0.0.0")
        XCTAssertEqual(stale.forNewWebsiteSession(ruleSet: rules), FilterPreferences())
        let current = FilterPreferences(enabled: true, rememberedRuleSetVersion: rules.ruleSetVersion)
        XCTAssertEqual(current.forNewWebsiteSession(ruleSet: rules), current)
        XCTAssertEqual(current.forNewWebsiteSession(ruleSet: nil), FilterPreferences())
        for platform in [SocialPlatform.facebook, .tiktok] {
            XCTAssertEqual(current.forNewWebsiteSession(ruleSet: try FilterRuleRegistry().rules(for: platform, mode: .website)), FilterPreferences())
        }
        XCTAssertEqual(current.forNewWebsiteSession(ruleSet: try FilterRuleRegistry().rules(for: .instagram, mode: .demo)), FilterPreferences())
    }

    func testExploreKindIsRestrictedToExactInstagramWebsiteDestination() throws {
        let set = try FilterRuleRegistry().rules(for: .instagram, mode: .website)
        let original = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(set)) as? [String: Any])
        for path in ["/explore/search", "/explore/tags", "/search", "/reels"] {
            var value = original
            var rules = try XCTUnwrap(value["rules"] as? [[String: Any]])
            rules[1]["pathPrefix"] = path; value["rules"] = rules
            XCTAssertThrowsError(try decode(value, mode: .website))
        }
        for platform in [SocialPlatform.facebook, .tiktok] {
            var value = original; value["platform"] = platform.rawValue
            XCTAssertThrowsError(try decode(value, platform: platform, mode: .website))
        }
        var value = original; value["scope"] = "demo"
        XCTAssertThrowsError(try decode(value))
    }
}
