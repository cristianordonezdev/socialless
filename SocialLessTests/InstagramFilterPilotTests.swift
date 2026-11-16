import XCTest
import WebKit
@testable import SocialLess

@MainActor final class InstagramFilterPilotTests: XCTestCase {
    private final class Loader: NSObject, WKNavigationDelegate {
        var finished = false
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { finished = true }
    }
    private enum FixtureError: Error { case timeout }
    private let ruleID = "instagram-reels-navigation"
    private let exploreID = "instagram-explore-navigation"

    private func waitUntil(_ condition: @MainActor () async throws -> Bool) async throws {
        for _ in 0..<100 {
            if try await condition() { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTFail("Timed out waiting for the synthetic Instagram fixture")
        throw FixtureError.timeout
    }
    private func harness(preferences: FilterPreferences = FilterPreferences(enabled: true)) -> (WKWebView, WebFilterController) {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        // Plain enabled preferences still require a check; remembered choices validate locally.
        let filters = WebFilterController(platform: .instagram, mode: .website,
            preferences: preferences, contentController: configuration.userContentController)
        let web = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 750), configuration: configuration)
        filters.attach(to: web)
        return (web, filters)
    }
    private func load(_ web: WKWebView, filters: WebFilterController, html: String = BrowserTestFixtures.instagramNavigation,
                      path: String = "/") async throws {
        let loader = Loader()
        web.navigationDelegate = loader
        web.loadHTMLString(html, baseURL: URL(string: "https://www.instagram.com" + path))
        try await waitUntil { loader.finished }
        web.navigationDelegate = nil
        filters.pageLoaded()
    }
    private func hidden(_ id: String, in web: WKWebView) async throws -> Bool {
        try await web.evaluateJavaScript("getComputedStyle(document.getElementById('\(id)')).display === 'none'") as? Bool == true
    }
    private func body(_ web: WKWebView) async throws -> String {
        try await web.evaluateJavaScript("document.body.innerHTML") as? String ?? ""
    }
    private func enable(_ filters: WebFilterController) async throws {
        filters.checkPage()
        try await waitUntil { filters.health == .ready }
        XCTAssertFalse(filters.preferences.enabled, "Detection must never opt in on the user's behalf")
        filters.update(FilterPreferences(enabled: true))
        try await waitUntil { filters.health == .active }
    }

    func testCheckIsReadOnlyAndExplicitEnableRestoresExactlyWhenOff() async throws {
        let (web, filters) = harness()
        defer { filters.shutdown() }
        try await load(web, filters: filters)
        try await waitUntil { filters.health == .off }
        XCTAssertFalse(filters.canEnable)
        let original = try await body(web)
        filters.update(FilterPreferences(enabled: true))
        XCTAssertFalse(filters.preferences.enabled)
        filters.checkPage()
        try await waitUntil { filters.health == .ready }
        XCTAssertTrue(filters.canEnable)
        XCTAssertEqual(filters.counts, [ruleID: 1])
        let checked = try await body(web)
        XCTAssertEqual(checked, original)
        filters.update(FilterPreferences(enabled: true))
        try await waitUntil { filters.health == .active }
        let reelsHidden = try await hidden("reels", in: web)
        XCTAssertTrue(reelsHidden)
        for id in ["home", "messages", "stories", "post", "postLink"] {
            let value = try await hidden(id, in: web)
            XCTAssertFalse(value, id)
        }
        filters.update(FilterPreferences(enabled: false))
        try await waitUntil { filters.health == .off }
        let restored = try await body(web)
        XCTAssertEqual(restored, original)
    }

    func testExactDestinationExcludesPostsAuthFormsAndForeignLinks() async throws {
        let (web, filters) = harness()
        defer { filters.shutdown() }
        let additional = """
        <nav>
          <a id="noSlash" href="/reels">Reels</a>
          <a id="query" href="/reels/?source=synthetic#top">Reels</a>
          <a id="item" href="/reels/sample/">Individual video</a>
          <a id="singular" href="/reel/sample/">Individual video</a>
          <a id="boundary" href="/reels-more/">Different destination</a>
          <a id="doubleSlash" href="/reels//">Ambiguous route</a>
          <a id="foreign" href="https://instagram.com.invalid/reels/">Foreign link</a>
          <a id="insecure" href="http://instagram.com/reels/">Insecure link</a>
          <a id="auth" href="/accounts/login/?next=/reels/">Sign in</a>
          <form><a id="form" href="/reels/">Form link</a></form>
          <div role="dialog"><a id="dialog" href="/reels/">Dialog link</a></div>
        </nav>
        <article><nav><a id="article" href="/reels/">Post navigation</a></nav></article>
        <div role="article"><nav><a id="roleArticle" href="/reels/">Post navigation</a></nav></div>
        """
        try await load(web, filters: filters, html: BrowserTestFixtures.instagramNavigation.replacingOccurrences(of: "</body>", with: additional + "</body>"))
        try await enable(filters)
        XCTAssertEqual(filters.counts, [ruleID: 3])
        for id in ["reels", "noSlash", "query"] {
            let value = try await hidden(id, in: web)
            XCTAssertTrue(value, id)
        }
        for id in ["item", "singular", "boundary", "doubleSlash", "foreign", "insecure", "auth", "form", "dialog", "article", "roleArticle"] {
            let value = try await hidden(id, in: web)
            XCTAssertFalse(value, id)
        }
    }

    func testNoVisibleNavigationMatchKeepsSwitchLockedUntilExplicitRecheck() async throws {
        for attribute in ["hidden", "style='visibility:hidden'", "style='display:none'"] {
            let (web, filters) = harness()
            let html = BrowserTestFixtures.instagramNavigation.replacingOccurrences(of: "id=\"reels\"", with: "id=\"reels\" \(attribute)")
            try await load(web, filters: filters, html: html)
            let original = try await body(web)
            filters.checkPage()
            try await waitUntil { filters.health == .noMatches }
            XCTAssertFalse(filters.canEnable)
            filters.update(FilterPreferences(enabled: true))
            XCTAssertFalse(filters.preferences.enabled)
            let unchanged = try await body(web)
            XCTAssertEqual(unchanged, original)
            _ = try await web.evaluateJavaScript("document.getElementById('navigation').insertAdjacentHTML('beforeend', '<a href=/reels/ id=late>Late navigation</a>');")
            // A check is one-shot; late DOM changes alone do not grant permission or hide anything.
            XCTAssertFalse(filters.canEnable)
            let visible = try await hidden("late", in: web)
            XCTAssertFalse(visible)
            try await enable(filters)
            filters.shutdown()
        }
    }

    func testSPAAuthTransitionsDynamicLinksAndPauseKeepRestorationWorking() async throws {
        let (web, filters) = harness()
        defer { filters.shutdown() }
        try await load(web, filters: filters)
        try await enable(filters)
        for route in ["/accounts/login/", "/consent/", "/challenge/", "/recovery/", "/%61ccounts/login/"] {
            _ = try await web.evaluateJavaScript("history.pushState({}, '', '\(route)');")
            try await waitUntil { filters.health == .unavailable }
            let value = try await hidden("reels", in: web)
            XCTAssertFalse(value)
            _ = try await web.evaluateJavaScript("history.replaceState({}, '', '/');")
            try await waitUntil { filters.health == .active }
        }
        filters.setPaused(true)
        try await waitUntil { filters.health == .paused }
        _ = try await web.evaluateJavaScript("document.getElementById('navigation').insertAdjacentHTML('beforeend', '<a href=/reels/ id=late>Late navigation</a>');")
        let paused = try await hidden("late", in: web)
        XCTAssertFalse(paused)
        filters.setPaused(false)
        try await waitUntil { filters.counts[self.ruleID] == 2 }
        _ = try await web.evaluateJavaScript("document.getElementById('late').href = '/direct/inbox/';")
        try await waitUntil { filters.counts[self.ruleID] == 1 }
        let messageLink = try await hidden("late", in: web)
        XCTAssertFalse(messageLink)
    }

    func testCanceledChecksAndTerminalStateCannotAuthorizeFiltering() async throws {
        let (web, filters) = harness()
        try await load(web, filters: filters)
        try await waitUntil { filters.health == .off }
        filters.checkPage()
        filters.setPaused(true)
        try await waitUntil { filters.health == .paused }
        XCTAssertFalse(filters.canEnable)
        filters.setPaused(false)
        try await waitUntil { filters.health == .off }
        filters.checkPage()
        filters.navigationStarted()
        filters.pageLoaded()
        try await waitUntil { filters.health == .off }
        XCTAssertFalse(filters.canEnable)
        try await enable(filters)
        filters.pageFailed()
        XCTAssertFalse(filters.canEnable)
        try await waitUntil { try await !self.hidden("reels", in: web) }
        XCTAssertEqual(filters.health, .failed)
        filters.pageLoaded()
        try await waitUntil { filters.health == .off }
        filters.checkPage()
        filters.shutdown()
        try await waitUntil { try await !self.hidden("reels", in: web) }
        XCTAssertFalse(filters.canEnable)
        filters.checkPage(); filters.update(FilterPreferences(enabled: true))
        XCTAssertEqual(filters.health, .off)
        XCTAssertTrue(web.configuration.userContentController.userScripts.isEmpty)
        let (_, fresh) = harness()
        XCTAssertFalse(fresh.canEnable)
        XCTAssertFalse(fresh.preferences.enabled)
        fresh.shutdown()
    }

    func testCSPFailureAfterSuccessfulCheckRestoresPage() async throws {
        let (web, filters) = harness()
        defer { filters.shutdown() }
        let html = BrowserTestFixtures.instagramNavigation.replacingOccurrences(of: "style-src 'unsafe-inline'", with: "style-src 'none'")
        try await load(web, filters: filters, html: html)
        let original = try await body(web)
        filters.checkPage()
        try await waitUntil { filters.health == .ready }
        filters.update(FilterPreferences(enabled: true))
        try await waitUntil { filters.health == .styleBlocked }
        let restored = try await body(web)
        XCTAssertEqual(restored, original)
        filters.update(FilterPreferences(enabled: false))
        try await waitUntil { filters.health == .off }
    }

    func testReelsIconLinkOutsideSemanticNavigationCanBeCheckedAndRestored() async throws {
        let (web, filters) = harness()
        defer { filters.shutdown() }
        try await load(web, filters: filters, html: BrowserTestFixtures.instagramUnmarkedNavigation)
        let original = try await body(web)
        try await enable(filters)
        let reelsHidden = try await hidden("reels", in: web)
        XCTAssertTrue(reelsHidden)
        for id in ["home", "messages", "stories", "post", "postLink"] {
            let value = try await hidden(id, in: web)
            XCTAssertFalse(value, id)
        }
        filters.update(FilterPreferences(enabled: false))
        try await waitUntil { filters.health == .off }
        let restored = try await body(web)
        XCTAssertEqual(restored, original)
    }

    func testUnrecognizedDestinationIsReportedWithoutHidingOrUnlocking() async throws {
        let (web, filters) = harness()
        defer { filters.shutdown() }
        let html = BrowserTestFixtures.instagramUnmarkedNavigation.replacingOccurrences(of: "aria-label=\"Reels\"", with: "aria-label=\"Unknown control\"")
        try await load(web, filters: filters, html: html)
        let original = try await body(web)
        filters.checkPage()
        try await waitUntil { filters.health == .unsupportedLayout }
        XCTAssertFalse(filters.canEnable)
        let checked = try await body(web)
        XCTAssertEqual(checked, original)
        // A supported label can arrive later, but the one-shot check must still be requested.
        _ = try await web.evaluateJavaScript("document.getElementById('reels').setAttribute('aria-label', 'Reels');")
        XCTAssertFalse(filters.canEnable)
        try await enable(filters)
        let hidden = try await hidden("reels", in: web)
        XCTAssertTrue(hidden)
    }

    func testPartialCoverageAndChangingIconLabelsNeverReportCompleteMatching() async throws {
        let (web, filters) = harness()
        defer { filters.shutdown() }
        let additional = "<div><a id='otherEntry' href='/reels/'><svg id='otherIcon' aria-label='Unknown' width='20' height='20'></svg>Other entry</a></div>"
        let html = BrowserTestFixtures.instagramUnmarkedNavigation.replacingOccurrences(of: "</body>", with: additional + "</body>")
        try await load(web, filters: filters, html: html)
        filters.checkPage()
        try await waitUntil { filters.health == .ready }
        filters.update(FilterPreferences(enabled: true))
        try await waitUntil { filters.health == .partial }
        XCTAssertEqual(filters.counts[ruleID], 1)
        let remaining = try await hidden("otherEntry", in: web)
        XCTAssertFalse(remaining)
        _ = try await web.evaluateJavaScript("document.getElementById('otherIcon').setAttribute('aria-label', 'Reels');")
        try await waitUntil { filters.health == .active && filters.counts[self.ruleID] == 2 }
        _ = try await web.evaluateJavaScript("document.getElementById('otherIcon').setAttribute('aria-label', 'Unknown');")
        try await waitUntil { filters.health == .partial && filters.counts[self.ruleID] == 1 }
        let restored = try await hidden("otherEntry", in: web)
        XCTAssertFalse(restored)
    }

    func testAccessibleLabelAloneCannotHidePostsFormsAuthOrForeignDestinations() async throws {
        let (web, filters) = harness()
        defer { filters.shutdown() }
        let additional = """
        <div><a id="directLabel" aria-label="Reels" href="/reels/">Recognized entry</a>
          <a id="individual" aria-label="Reels" href="/reel/sample/">Individual video</a>
          <a id="child" aria-label="Reels" href="/reels/sample/">Individual video</a>
          <a id="boundary" aria-label="Reels" href="/reels-more/">Different destination</a>
          <a id="foreign" aria-label="Reels" href="https://instagram.com.invalid/reels/">Foreign</a>
          <a id="insecure" aria-label="Reels" href="http://instagram.com/reels/">Insecure</a>
          <a id="auth" aria-label="Reels" href="/accounts/login/?next=/reels/">Login</a>
          <button id="noDestination" aria-label="Reels">Button with no link</button>
        </div>
        <article><a id="articleLink" aria-label="Reels" href="/reels/">Post</a></article>
        <div role="article"><a id="roleArticleLink" aria-label="Reels" href="/reels/">Post</a></div>
        <form><a id="formLink" aria-label="Reels" href="/reels/">Form</a></form>
        <div role="dialog"><a id="dialogLink" aria-label="Reels" href="/reels/">Dialog</a></div>
        """
        try await load(web, filters: filters, html: BrowserTestFixtures.instagramUnmarkedNavigation.replacingOccurrences(of: "</body>", with: additional + "</body>"))
        let original = try await body(web)
        try await enable(filters)
        XCTAssertEqual(filters.counts[ruleID], 2)
        for id in ["individual", "child", "boundary", "foreign", "insecure", "auth", "noDestination", "articleLink", "roleArticleLink", "formLink", "dialogLink", "postLink"] {
            let value = try await hidden(id, in: web)
            XCTAssertFalse(value, id)
        }
        filters.update(FilterPreferences(enabled: false))
        try await waitUntil { filters.health == .off }
        let restored = try await body(web)
        XCTAssertEqual(restored, original)
    }

    func testWebsiteRemovingMarkerIsRepairedAndStyleOverrideFailsOpen() async throws {
        let (web, filters) = harness()
        defer { filters.shutdown() }
        try await load(web, filters: filters, html: BrowserTestFixtures.instagramUnmarkedNavigation)
        try await enable(filters)
        _ = try await web.evaluateJavaScript("""
        (() => {
            const a = document.getElementById('reels');
            for (const attribute of a.getAttributeNames()) {
                if (attribute.startsWith('data-socialless-')) a.removeAttribute(attribute);
            }
        })()
        """)
        try await waitUntil { try await self.hidden("reels", in: web) }
        _ = try await web.evaluateJavaScript("document.getElementById('reels').style.setProperty('display', 'block', 'important');")
        try await waitUntil { filters.health == .styleBlocked }
        let restored = try await hidden("reels", in: web)
        XCTAssertFalse(restored)
        filters.update(FilterPreferences(enabled: false))
        try await waitUntil { filters.health == .off }
        let siteStyle = try await web.evaluateJavaScript("document.getElementById('reels').style.getPropertyPriority('display')") as? String
        XCTAssertEqual(siteStyle, "important", "Restoration must preserve the site's own edits")
    }

    private func remembered(enabled: Bool = true) throws -> FilterPreferences {
        FilterPreferences(enabled: enabled, rememberedRuleSetVersion:
            try FilterRuleRegistry().rules(for: .instagram, mode: .website).ruleSetVersion)
    }

    func testRememberedChoiceChecksAutomaticallyAndOffRestoresAcrossDocuments() async throws {
        let (web, filters) = harness(preferences: try remembered())
        defer { filters.shutdown() }
        try await load(web, filters: filters, html: BrowserTestFixtures.instagramUnmarkedNavigation)
        try await waitUntil { filters.health == .active }
        XCTAssertTrue(filters.canRemember)
        let hidden = try await hidden("reels", in: web)
        XCTAssertTrue(hidden)
        filters.update(try remembered(enabled: false))
        try await waitUntil { filters.health == .off }
        let restored = try await self.hidden("reels", in: web)
        XCTAssertFalse(restored)
        try await load(web, filters: filters)
        try await waitUntil { filters.health == .off }
        let stillVisible = try await self.hidden("reels", in: web)
        XCTAssertFalse(stillVisible)
        let (freshWeb, freshFilters) = harness(preferences: filters.preferences)
        defer { freshFilters.shutdown() }
        try await load(freshWeb, filters: freshFilters)
        try await waitUntil { freshFilters.health == .off }
        XCTAssertTrue(freshFilters.canEnable, "Remembered Off can be enabled with automatic checking")
        freshFilters.update(try remembered())
        try await waitUntil { freshFilters.health == .active }
    }

    func testAutomaticCheckWaitsForVisibleControlsAndRejectsPartialNewDocuments() async throws {
        let (web, filters) = harness(preferences: try remembered())
        defer { filters.shutdown() }
        let hiddenLayout = BrowserTestFixtures.instagramUnmarkedNavigation
            .replacingOccurrences(of: "id=\"reels\"", with: "id=\"reels\" hidden")
        try await load(web, filters: filters, html: hiddenLayout)
        try await waitUntil { filters.health == .noMatches }
        let markers = try await web.evaluateJavaScript("document.getElementById('reels').getAttributeNames().every(n => !n.startsWith('data-socialless-'))") as? Bool
        XCTAssertEqual(markers, true)
        _ = try await web.evaluateJavaScript("document.getElementById('reels').removeAttribute('hidden');")
        try await waitUntil { filters.health == .active }
        let unsupported = "<a id='unknown' href='/reels/'>Unrecognized entry</a>"
        let partial = BrowserTestFixtures.instagramUnmarkedNavigation.replacingOccurrences(of: "</body>", with: unsupported + "</body>")
        try await load(web, filters: filters, html: partial)
        try await waitUntil { filters.health == .unsupportedLayout }
        for id in ["reels", "unknown", "messages", "stories", "post"] {
            let hidden = try await hidden(id, in: web)
            XCTAssertFalse(hidden, id)
        }
        _ = try await web.evaluateJavaScript("document.getElementById('unknown').setAttribute('aria-label', 'Reels');")
        try await waitUntil { filters.health == .active && filters.counts[self.ruleID] == 2 }
        _ = try await web.evaluateJavaScript("document.getElementById('unknown').removeAttribute('aria-label');")
        try await waitUntil { filters.health == .unsupportedLayout }
        let restored = try await hidden("reels", in: web)
        XCTAssertFalse(restored, "Loss of compatibility must restore all automatically hidden controls")
    }

    func testRememberedChoiceHonorsAuthPauseFailureAndTerminalStates() async throws {
        let (web, filters) = harness(preferences: try remembered())
        try await load(web, filters: filters, path: "/accounts/login/")
        try await waitUntil { filters.health == .unavailable }
        let authVisible = try await hidden("reels", in: web)
        XCTAssertFalse(authVisible)
        _ = try await web.evaluateJavaScript("history.replaceState({}, '', '/');")
        try await waitUntil { filters.health == .active }
        filters.setPaused(true)
        try await waitUntil { filters.health == .paused }
        let pausedVisible = try await hidden("reels", in: web)
        XCTAssertFalse(pausedVisible)
        filters.setPaused(false)
        try await waitUntil { filters.health == .active }
        filters.pageFailed()
        try await waitUntil { try await !self.hidden("reels", in: web) }
        XCTAssertEqual(filters.health, .failed)
        filters.pageLoaded()
        try await waitUntil { filters.health == .active }
        filters.shutdown()
        filters.pageLoaded(); filters.setPaused(false); filters.update(try remembered())
        try await waitUntil { try await !self.hidden("reels", in: web) }
        XCTAssertEqual(filters.health, .off)
        XCTAssertFalse(filters.canEnable)
        XCTAssertTrue(web.configuration.userContentController.userScripts.isEmpty)
    }

    func testRememberingRequiresActiveTrialAndOldRuleConsentCannotEnable() async throws {
        let (web, filters) = harness()
        defer { filters.shutdown() }
        try await load(web, filters: filters)
        filters.update(try remembered())
        XCTAssertNil(filters.preferences.rememberedRuleSetVersion)
        XCTAssertFalse(filters.preferences.enabled)
        try await enable(filters)
        XCTAssertTrue(filters.canRemember)
        filters.update(try remembered())
        XCTAssertNotNil(filters.preferences.rememberedRuleSetVersion)
        let (changedWeb, changed) = harness(preferences: FilterPreferences(enabled: true, rememberedRuleSetVersion: "0.0.0"))
        defer { changed.shutdown() }
        try await load(changedWeb, filters: changed)
        try await waitUntil { changed.health == .off }
        XCTAssertFalse(changed.canEnable)
        XCTAssertFalse(changed.preferences.enabled)
    }

    func testAutomaticStyleFailureRestoresAndOffRemainsAvailable() async throws {
        let (web, filters) = harness(preferences: try remembered())
        defer { filters.shutdown() }
        let html = BrowserTestFixtures.instagramNavigation.replacingOccurrences(of: "style-src 'unsafe-inline'", with: "style-src 'none'")
        try await load(web, filters: filters, html: html)
        try await waitUntil { filters.health == .styleBlocked }
        XCTAssertTrue(filters.canEnable, "The saved choice must remain possible to turn off after failure")
        let restored = try await hidden("reels", in: web)
        XCTAssertFalse(restored)
        filters.update(try remembered(enabled: false))
        try await waitUntil { filters.health == .off }
    }

    func testRememberedIndividualRuleOffIsRespected() async throws {
        var preferences = try remembered()
        preferences.ruleOverrides[ruleID] = false
        let (web, filters) = harness(preferences: preferences)
        defer { filters.shutdown() }
        try await load(web, filters: filters)
        try await waitUntil { filters.health == .off }
        let visible = try await hidden("reels", in: web)
        XCTAssertFalse(visible)
        preferences.ruleOverrides[ruleID] = true
        filters.update(preferences)
        try await waitUntil { filters.health == .active }
    }

    func testExploreCheckPreservesActiveReelsAndEachSwitchRestoresIndependently() async throws {
        let (web, filters) = harness()
        defer { filters.shutdown() }
        try await load(web, filters: filters, html: BrowserTestFixtures.instagramUnmarkedNavigation)
        try await enable(filters)
        let explore = try XCTUnwrap(filters.ruleSet?.rules.first { $0.id == exploreID })
        XCTAssertFalse(filters.canEnableRule(explore))
        var choice = filters.preferences
        choice.ruleOverrides[exploreID] = true
        filters.update(choice)
        XCTAssertFalse(filters.preferences.isEnabled(explore), "Reels approval must not authorize Explore")
        let before = try await body(web)
        filters.checkRule(exploreID)
        try await waitUntil { filters.ruleCheckHealth[self.exploreID] == .ready }
        let checked = try await body(web)
        XCTAssertEqual(checked, before, "A successful independent probe must leave the page unchanged")
        let reelsStillHidden = try await hidden("reels", in: web)
        let exploreStillVisible = try await hidden("explore", in: web)
        XCTAssertTrue(reelsStillHidden); XCTAssertFalse(exploreStillVisible)
        XCTAssertEqual(filters.health, .active)
        XCTAssertTrue(filters.canEnableRule(explore))
        choice = filters.preferences; choice.ruleOverrides[exploreID] = true
        filters.update(choice)
        try await waitUntil { filters.counts[self.exploreID] == 1 && filters.health == .active }
        let searchHidden = try await hidden("search", in: web)
        XCTAssertFalse(searchHidden)
        choice.ruleOverrides[ruleID] = false; filters.update(choice)
        try await waitUntil { try await !self.hidden("reels", in: web) }
        let exploreHidden = try await hidden("explore", in: web)
        XCTAssertTrue(exploreHidden)
        choice.enabled = false; filters.update(choice)
        try await waitUntil { filters.health == .off }
        let restored = try await hidden("explore", in: web)
        XCTAssertFalse(restored)
    }

    func testExploreExactPathExcludesSearchPostsAuthAndForeignLinks() async throws {
        let extra = """
        <nav><a id="searchExtra" href="/explore/search/" aria-label="Explore">Search</a>
        <a id="tags" href="/explore/tags/sample/" aria-label="Explore">Tag</a>
        <a id="foreignExplore" href="https://example.test/explore/" aria-label="Explore">Other</a>
        <a id="loginExplore" href="/accounts/login/?next=/explore/" aria-label="Explore">Login</a></nav>
        <article><a id="postExplore" href="/explore/" aria-label="Explore">Post</a></article>
        <form><a id="formExplore" href="/explore/" aria-label="Explore">Form</a></form>
        <div role="dialog"><a id="dialogExplore" href="/explore/" aria-label="Explore">Dialog</a></div>
        """
        let (web, filters) = harness()
        defer { filters.shutdown() }
        try await load(web, filters: filters, html: BrowserTestFixtures.instagramUnmarkedNavigation.replacingOccurrences(of: "</body>", with: extra + "</body>"))
        try await waitUntil { filters.health == .off }
        filters.checkRule(exploreID)
        try await waitUntil { filters.ruleCheckHealth[self.exploreID] == .ready }
        // Explore can be tried even when Reels has not been checked.
        var choice = FilterPreferences(enabled: true, ruleOverrides: [exploreID: true])
        filters.update(choice)
        try await waitUntil { filters.health == .active && filters.counts[self.exploreID] == 1 }
        for id in ["reels", "search", "searchExtra", "tags", "foreignExplore", "loginExplore", "postExplore", "formExplore", "dialogExplore", "messages", "stories"] {
            let value = try await hidden(id, in: web)
            XCTAssertFalse(value, id)
        }
        choice.enabled = false; filters.update(choice)
        try await waitUntil { filters.health == .off }
    }

    func testMissingExploreAndCanceledProbesCannotAuthorizeIt() async throws {
        let (web, filters) = harness()
        defer { filters.shutdown() }
        let missing = BrowserTestFixtures.instagramUnmarkedNavigation.replacingOccurrences(of: "href=\"/explore/\"", with: "href=\"/explore/search/\"")
        try await load(web, filters: filters, html: missing)
        try await enable(filters)
        let original = try await body(web)
        filters.checkRule(exploreID)
        try await waitUntil { filters.ruleCheckHealth[self.exploreID] == .noMatches }
        let checked = try await body(web)
        XCTAssertEqual(checked, original, "The independent check must not restore or replace active markers")
        XCTAssertFalse(filters.checkedRuleIDs.contains(exploreID))
        _ = try await web.evaluateJavaScript("document.getElementById('explore').href = '/explore/';")
        filters.checkRule(exploreID); filters.setPaused(true)
        try await waitUntil { filters.health == .paused }
        XCTAssertFalse(filters.checkedRuleIDs.contains(exploreID))
        filters.setPaused(false)
        try await waitUntil { filters.health == .active }
        filters.checkRule(exploreID); filters.navigationStarted(); filters.pageLoaded()
        try await waitUntil { filters.health == .active }
        XCTAssertFalse(filters.checkedRuleIDs.contains(exploreID))
        filters.checkRule(exploreID); filters.shutdown()
        XCTAssertFalse(filters.checkedRuleIDs.contains(exploreID))
        XCTAssertEqual(filters.health, .off)
    }

    func testRememberedExploreRequiresSeparateConsentAndFailureKeepsReelsActive() async throws {
        var choice = try remembered()
        choice.ruleOverrides[exploreID] = true
        let (web, filters) = harness(preferences: choice)
        defer { filters.shutdown() }
        try await load(web, filters: filters, html: BrowserTestFixtures.instagramUnmarkedNavigation)
        try await waitUntil { filters.health == .active }
        let initiallyVisible = try await hidden("explore", in: web)
        XCTAssertFalse(initiallyVisible, "Remembering Reels alone never authorizes Explore")
        filters.checkRule(exploreID)
        try await waitUntil { filters.ruleCheckHealth[self.exploreID] == .ready }
        choice.approvedRuleIDs = [exploreID]
        filters.update(choice)
        try await waitUntil { filters.counts[self.exploreID] == 1 && filters.health == .active }
        let (freshWeb, fresh) = harness(preferences: filters.preferences)
        defer { fresh.shutdown() }
        let unsupported = "<a href='/explore/' id='unknownExplore'>Unknown control</a>"
        try await load(freshWeb, filters: fresh, html: BrowserTestFixtures.instagramUnmarkedNavigation.replacingOccurrences(of: "</body>", with: unsupported + "</body>"))
        try await waitUntil { fresh.health == .partial }
        let reelsHidden = try await hidden("reels", in: freshWeb)
        let exploreHidden = try await hidden("explore", in: freshWeb)
        XCTAssertTrue(reelsHidden); XCTAssertFalse(exploreHidden)
        _ = try await freshWeb.evaluateJavaScript("history.pushState({}, '', '/accounts/login/');")
        try await waitUntil { fresh.health == .unavailable }
        let authHidden = try await hidden("reels", in: freshWeb)
        XCTAssertFalse(authHidden)
    }

    func testRememberingExploreOnlyDoesNotActivateUncheckedReels() async throws {
        let (web, filters) = harness()
        defer { filters.shutdown() }
        try await load(web, filters: filters, html: BrowserTestFixtures.instagramUnmarkedNavigation)
        try await waitUntil { filters.health == .off }
        filters.checkRule(exploreID)
        try await waitUntil { filters.ruleCheckHealth[self.exploreID] == .ready }
        filters.update(FilterPreferences(enabled: true, ruleOverrides: [exploreID: true]))
        try await waitUntil { filters.health == .active }
        var choice = filters.preferences
        choice.rememberedRuleSetVersion = filters.ruleSet?.ruleSetVersion
        choice.approvedRuleIDs = [exploreID]
        filters.update(choice)
        let (freshWeb, fresh) = harness(preferences: filters.preferences)
        defer { fresh.shutdown() }
        try await load(freshWeb, filters: fresh, html: BrowserTestFixtures.instagramUnmarkedNavigation)
        try await waitUntil { fresh.health == .active && fresh.counts[self.exploreID] == 1 }
        let reelsHidden = try await hidden("reels", in: freshWeb)
        let exploreHidden = try await hidden("explore", in: freshWeb)
        XCTAssertFalse(reelsHidden); XCTAssertTrue(exploreHidden)
    }
}
