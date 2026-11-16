import XCTest
import WebKit
@testable import SocialLess

@MainActor final class FilterEngineTests: XCTestCase {
    private final class Loader: NSObject, WKNavigationDelegate {
        var finished = false
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { finished = true }
    }
    private struct Registry: PlatformRulesProviding {
        let set: FilterRuleSet
        func rules(for platform: SocialPlatform, mode: BrowsingMode) throws -> FilterRuleSet { set }
    }
    private struct BrokenRegistry: PlatformRulesProviding {
        func rules(for platform: SocialPlatform, mode: BrowsingMode) throws -> FilterRuleSet { throw FilterRuleError.invalidBundle }
    }
    private enum FixtureError: Error { case timeout }

    private func waitUntil(_ condition: @MainActor () async throws -> Bool) async throws {
        for _ in 0..<100 {
            if try await condition() { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTFail("Timed out waiting for the local WebKit fixture")
        throw FixtureError.timeout
    }
    private func fixture() throws -> String {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "filter_safety_fixture", withExtension: "html"))
        return try String(contentsOf: url, encoding: .utf8)
    }
    private func load(_ web: WKWebView, html: String, baseURL: URL? = nil) async throws {
        let loader = Loader()
        web.navigationDelegate = loader
        web.loadHTMLString(html, baseURL: baseURL)
        try await waitUntil { loader.finished }
        web.navigationDelegate = nil
    }
    private func harness(mode: BrowsingMode = .demo, enabled: Bool = true) throws -> (WKWebView, WebFilterController) {
        var data = try JSONEncoder().encode(FilterRuleRegistry().rules(for: .instagram, mode: .demo))
        if mode == .website {
            var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            json["scope"] = "website" // Synthetic rules, used only with in-memory fixture HTML.
            data = try JSONSerialization.data(withJSONObject: json)
        }
        let rules = try FilterRuleRegistry.decode(data, platform: .instagram, mode: mode)
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let filters = WebFilterController(platform: .instagram, mode: mode, preferences: FilterPreferences(enabled: enabled),
                                          contentController: configuration.userContentController, registry: Registry(set: rules))
        let web = WKWebView(frame: .zero, configuration: configuration)
        filters.attach(to: web)
        return (web, filters)
    }
    private func hidden(_ id: String, in web: WKWebView) async throws -> Bool {
        try await web.evaluateJavaScript("getComputedStyle(document.getElementById('\(id)')).display === 'none'") as? Bool == true
    }
    private func diagnostics(_ web: WKWebView) async throws -> [String: Any] {
        let value = try await isolated("JSON.stringify(globalThis.sociallessFilters.diagnostics())", in: web)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(value.utf8)) as? [String: Any])
    }
    private func isolated(_ source: String, in web: WKWebView) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            web.evaluateJavaScript(source, in: nil, in: FilterScriptFactory.world) { result in
                switch result {
                case .success(let value): continuation.resume(returning: value as? String ?? "")
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
    }

    func testOnlyNavigationTargetsHiddenAndOriginalDOMRestoredWithoutReload() async throws {
        let (web, filters) = try harness(enabled: false)
        defer { filters.shutdown() }
        try await load(web, html: fixture())
        let original = try await web.evaluateJavaScript("document.body.innerHTML") as? String
        filters.update(FilterPreferences(enabled: true))
        try await waitUntil { filters.health == .active }
        for id in ["discover", "child", "videos", "prehidden", "roleNav"] {
            let value = try await hidden(id, in: web)
            XCTAssertTrue(value, id)
        }
        for id in ["boundary", "foreign", "prefix", "otherPlatform", "insecure", "port", "userinfo",
                   "query", "recovery", "encodedRecovery", "inForm", "inDialog", "inPost", "friendVideo", "input"] {
            let value = try await hidden(id, in: web)
            XCTAssertFalse(value, id)
        }
        let pageWorld = try await web.evaluateJavaScript("typeof globalThis.sociallessFilters") as? String
        XCTAssertEqual(pageWorld, "undefined", "The website cannot access the filter control object")
        XCTAssertEqual(filters.counts, ["demo-discovery": 4, "demo-short-videos": 1])
        filters.update(FilterPreferences(enabled: true, ruleOverrides: ["demo-discovery": false]))
        try await waitUntil { filters.counts["demo-discovery"] == nil && filters.health == .active }
        let restoredDiscover = try await hidden("discover", in: web), hiddenVideos = try await hidden("videos", in: web)
        XCTAssertFalse(restoredDiscover); XCTAssertTrue(hiddenVideos)
        filters.update(FilterPreferences(enabled: false))
        try await waitUntil { filters.health == .off }
        let restored = try await web.evaluateJavaScript("document.body.innerHTML") as? String
        XCTAssertEqual(restored, original, "Restoration preserves preexisting hidden/style/class attributes exactly")
        let state = try await diagnostics(web)
        XCTAssertEqual(state["observing"] as? Bool, false)
        XCTAssertEqual(state["marked"] as? Int, 0)
    }

    func testMutationBurstSubtreeReplacementAndHrefChangesAreThrottled() async throws {
        let (web, filters) = try harness()
        defer { filters.shutdown() }
        try await load(web, html: fixture())
        try await waitUntil { filters.health == .active }
        let initialPasses = try await diagnostics(web)["passes"] as? Int ?? 0
        _ = try await web.evaluateJavaScript("""
        (() => {
            const nav = document.createElement('nav'); nav.id = 'dynamic';
            document.body.appendChild(nav);
            for (let i = 0; i < 100; i++) {
                const a = document.createElement('a'); a.href = 'https://instagram.com/socialless-demo/discover/';
                a.id = 'added-' + i; a.textContent = 'Synthetic navigation'; nav.appendChild(a);
            }
        })()
        """)
        try await waitUntil { filters.counts["demo-discovery"] == 104 }
        let finalPasses = try await diagnostics(web)["passes"] as? Int ?? 0
        XCTAssertLessThanOrEqual(finalPasses - initialPasses, 2, "A mutation burst must not trigger a pass per node")
        _ = try await web.evaluateJavaScript("document.getElementById('added-0').href = 'https://instagram.com/accounts/login/'; document.getElementById('dynamic').setAttribute('aria-label', 'Site-owned label');")
        try await waitUntil { filters.counts["demo-discovery"] == 103 }
        let nowVisible = try await hidden("added-0", in: web)
        XCTAssertFalse(nowVisible)
        _ = try await web.evaluateJavaScript("document.getElementById('navigation').remove(); document.getElementById('dynamic').remove();")
        try await waitUntil { filters.counts["demo-discovery"] == 1 }
        let settled = try await diagnostics(web)["passes"] as? Int
        try await Task.sleep(for: .milliseconds(700))
        let after = try await diagnostics(web)["passes"] as? Int
        XCTAssertEqual(after, settled, "No recursive observer loop on our own writes")
    }

    func testTurningOffCancelsPendingWorkAndShutdownRemovesScripts() async throws {
        let (web, filters) = try harness()
        try await load(web, html: fixture())
        try await waitUntil { filters.health == .active }
        _ = try await web.evaluateJavaScript("document.getElementById('discover').setAttribute('href', 'https://instagram.com/socialless-demo/discover/new');")
        filters.update(FilterPreferences(enabled: false))
        try await waitUntil { filters.health == .off }
        try await Task.sleep(for: .milliseconds(450))
        let visible = try await hidden("discover", in: web)
        XCTAssertFalse(visible)
        let state = try await diagnostics(web)
        XCTAssertEqual(state["pending"] as? Bool, false)
        filters.shutdown()
        XCTAssertTrue(web.configuration.userContentController.userScripts.isEmpty)
        try await waitUntil {
            try await self.isolated("typeof globalThis.sociallessFilters", in: web) == "undefined"
        }
        filters.update(FilterPreferences(enabled: true)); filters.pageLoaded()
        XCTAssertEqual(filters.health, .off)
        XCTAssertTrue(web.configuration.userContentController.userScripts.isEmpty)
    }

    func testNoMatchesPauseAndResumeAreHonestAndReversible() async throws {
        let (web, filters) = try harness()
        defer { filters.shutdown() }
        try await load(web, html: "<html><body><nav id='empty'></nav></body></html>")
        try await waitUntil { filters.health == .noMatches }
        filters.setPaused(true)
        try await waitUntil { filters.health == .paused }
        let pausedState = try await diagnostics(web)
        XCTAssertEqual(pausedState["observing"] as? Bool, false)
        _ = try await web.evaluateJavaScript("document.getElementById('empty').innerHTML = '<a id=late href=https://instagram.com/socialless-demo/discover/>Late sample</a>';")
        let pausedVisible = try await hidden("late", in: web)
        XCTAssertFalse(pausedVisible)
        filters.setPaused(false)
        try await waitUntil { filters.health == .active }
        let resumedHidden = try await hidden("late", in: web)
        XCTAssertTrue(resumedHidden)
    }

    func testForeignHostsProtectedDocumentsAndDemoScopeDoNotMutate() async throws {
        for (mode, address) in [(BrowsingMode.website, "https://instagram.com.evil.invalid/"),
                                (.website, "https://facebook.com/"), (.website, "https://instagram.com/accounts/login/"),
                                (.website, "https://instagram.com/%61ccounts/login/"),
                                (.website, "http://instagram.com/"), (.demo, "https://instagram.com/")] {
            let (web, filters) = try harness(mode: mode)
            try await load(web, html: fixture(), baseURL: URL(string: address))
            filters.pageLoaded()
            try await waitUntil { filters.health == .unavailable }
            let visible = try await hidden("discover", in: web)
            XCTAssertFalse(visible, address)
            let object = try await isolated("typeof globalThis.sociallessFilters", in: web)
            XCTAssertEqual(object, "undefined")
            filters.shutdown()
        }
    }

    func testSyntheticWebsiteRulesRecheckSPAAuthRoutesAndRestoreAfterNavigation() async throws {
        let (web, filters) = try harness(mode: .website)
        defer { filters.shutdown() }
        try await load(web, html: fixture(), baseURL: URL(string: "https://www.instagram.com/"))
        filters.checkPage()
        try await waitUntil { filters.health == .ready }
        filters.update(FilterPreferences(enabled: true))
        try await waitUntil { filters.health == .active }
        _ = try await web.evaluateJavaScript("history.pushState({}, '', '/accounts/login/');")
        try await waitUntil { filters.health == .unavailable }
        let visible = try await hidden("discover", in: web)
        XCTAssertFalse(visible)
        _ = try await web.evaluateJavaScript("history.replaceState({}, '', '/');")
        try await waitUntil { filters.health == .active }
        filters.update(FilterPreferences(enabled: false))
        try await waitUntil { filters.health == .off }
        try await load(web, html: fixture(), baseURL: URL(string: "https://www.instagram.com/new-page/"))
        filters.pageLoaded()
        try await waitUntil { filters.health == .off }
        let stillVisible = try await hidden("discover", in: web)
        XCTAssertFalse(stillVisible)
    }

    func testCSSFailureAndWorkLimitFailOpen() async throws {
        for overload in [false, true] {
            let (web, filters) = try harness()
            var html = try fixture()
            if overload {
                let links = String(repeating: "<a href='https://instagram.com/socialless-demo/discover/'>Synthetic link</a>", count: 1001)
                html = html.replacingOccurrences(of: "</body>", with: "<nav>\(links)</nav></body>")
            } else {
                html = html.replacingOccurrences(of: "style-src 'unsafe-inline'", with: "style-src 'none'")
            }
            try await load(web, html: html)
            try await waitUntil { filters.health == (overload ? .failed : .styleBlocked) }
            let visible = try await hidden("discover", in: web)
            XCTAssertFalse(visible)
            let state = try await diagnostics(web)
            XCTAssertEqual(state["observing"] as? Bool, false)
            XCTAssertEqual(state["marked"] as? Int, 0)
            filters.shutdown()
        }
    }

    func testMalformedRegistryAndUnavailableSitesNeverInstallScripts() async throws {
        let broken = BrowserController(configuration: try SessionConfiguration(platform: .instagram, intent: .checkFriends, duration: 300, mode: .demo),
                                       rules: BrokenRegistry(), canNavigate: { true })
        XCTAssertEqual(broken.filters.health, .failed)
        XCTAssertTrue(broken.webView.configuration.userContentController.userScripts.isEmpty)
        broken.shutdown()
        for platform in [SocialPlatform.facebook, .tiktok] {
            let browser = BrowserController(configuration: try SessionConfiguration(platform: platform, intent: .checkFriends, duration: 300, mode: .website),
                                            filterPreferences: FilterPreferences(enabled: true), canNavigate: { true })
            XCTAssertEqual(browser.filters.health, .unavailable)
            XCTAssertEqual(browser.webView.configuration.userContentController.userScripts.count, 1)
            XCTAssertEqual(browser.webView.configuration.userContentController.userScripts.first?.source, BrowserController.deliberateVideoPlayback)
            browser.shutdown()
        }
    }

    func testAllDemoPagesCanFilterAndRestoreThroughBrowserController() async throws {
        for platform in SocialPlatform.allCases {
            let browser = BrowserController(configuration: try SessionConfiguration(platform: platform, intent: .checkFriends, duration: 300, mode: .demo),
                                            filterPreferences: FilterPreferences(enabled: true), canNavigate: { true })
            browser.loadHome()
            try await waitUntil { !browser.loading && browser.filters.health == .active }
            XCTAssertEqual(browser.filters.counts, ["demo-discovery": 1, "demo-short-videos": 1])
            let friendsHidden = try await hidden("demo-friends", in: browser.webView)
            XCTAssertFalse(friendsHidden)
            browser.filters.update(FilterPreferences(enabled: false))
            try await waitUntil { browser.filters.health == .off }
            let discoverHidden = try await hidden("demo-discover", in: browser.webView)
            XCTAssertFalse(discoverHidden)
            browser.shutdown()
        }
    }
}
