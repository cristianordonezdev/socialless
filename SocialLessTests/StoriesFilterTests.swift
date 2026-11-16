import XCTest
import WebKit
@testable import SocialLess

@MainActor final class StoriesFilterTests: XCTestCase {
    private final class Loader: NSObject, WKNavigationDelegate {
        var done = false
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { done = true }
    }
    private func wait(_ condition: () async throws -> Bool) async throws {
        for _ in 0..<100 {
            if try await condition() { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTFail("Synthetic stories condition timed out")
    }
    private func harness(path: String = "/stories/friend/123/", body: String = "<header><a href='/friend/'>friend</a><span id='badge'>Today</span></header><p>Fictional story</p>", css: String = "'unsafe-inline'", origin: String = "https://www.instagram.com") async throws -> (WKWebView, StoriesFilterController) {
        let config = WKWebViewConfiguration(); config.websiteDataStore = .nonPersistent()
        let web = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: config)
        let filter = StoriesFilterController(webView: web)
        let loader = Loader(); web.navigationDelegate = loader
        web.loadHTMLString("<html><head><meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'none'; style-src \(css)\"></head><body><main>\(body)</main></body></html>", baseURL: URL(string: origin + path))
        try await wait { loader.done }; web.navigationDelegate = nil
        filter.pageLoaded(); return (web, filter)
    }
    func testSponsoredStoryReversibleAndDynamicBadgeRestores() async throws {
        let (web, filter) = try await harness()
        defer { filter.shutdown() }
        let original = try await web.evaluateJavaScript("document.body.innerHTML") as? String
        filter.setEnabled(true)
        try await wait { filter.status == "Stories filter active" }
        _ = try await web.evaluateJavaScript("document.getElementById('badge').textContent='Publicidad';")
        try await wait { filter.isBlocked }
        XCTAssertEqual(filter.hiddenCount, 1)
        _ = try await web.evaluateJavaScript("document.getElementById('badge').textContent='Today';")
        try await wait { !filter.isBlocked }
        filter.setEnabled(false)
        try await wait { filter.status == "Stories filter off" }
        let restored = try await web.evaluateJavaScript("document.body.innerHTML") as? String
        XCTAssertEqual(restored, original)
    }
    func testImportedAccountsRouteChangesPauseAndTerminal() async throws {
        let (web, filter) = try await harness()
        filter.updateAccounts(["friend"]); filter.setEnabled(true)
        try await wait { filter.status == "Stories filter active" }
        _ = try await web.evaluateJavaScript("history.pushState({},'', '/stories/other/456/'); const a=document.querySelector('header a'); a.href='/other/'; a.textContent='other';")
        try await wait { filter.isBlocked }
        filter.setPaused(true); try await wait { !filter.isBlocked }
        filter.setPaused(false); try await wait { filter.isBlocked }
        filter.pageFailed(); try await wait { !filter.isBlocked }
        filter.pageLoaded(); try await wait { filter.isBlocked }
        filter.updateAccounts(["other"]); XCTAssertFalse(filter.enabled)
        filter.setEnabled(true); try await wait { filter.status == "Stories filter active" }
        filter.shutdown(); filter.setEnabled(true); filter.pageLoaded()
        XCTAssertFalse(filter.enabled); XCTAssertFalse(filter.isBlocked)
    }
    func testProtectedRoutesCaptionAndProfileNamesAreNotAdLabels() async throws {
        for path in ["/", "/direct/inbox/", "/stories/highlights/123/", "/accounts/login/"] {
            let (web, filter) = try await harness(path: path)
            filter.setEnabled(true)
            try await wait { filter.status == "Filter applies to the stories viewer only" }
            XCTAssertFalse(filter.isBlocked); _ = web.url; filter.shutdown()
        }
        let (web, filter) = try await harness(path: "/stories/sponsored/123/", body: "<header><a href='/sponsored/'>Sponsored</a></header><p>Publicidad</p>")
        defer { filter.shutdown(); _ = web.url }
        filter.setEnabled(true); try await wait { filter.status == "Stories filter active" }
        XCTAssertFalse(filter.isBlocked)
    }
    func testCSSFailureAndUnsupportedViewerDoNotClaimSuccess() async throws {
        let (web, filter) = try await harness(body: "<header><span>Sponsored</span></header>", css: "'none'")
        filter.setEnabled(true); try await wait { filter.status == "Website prevented hiding stories" }
        XCTAssertFalse(filter.isBlocked); _ = web.url; filter.shutdown()
        let (secondWeb, ambiguous) = try await harness(body: "<div role='dialog'>Fictional nested viewer</div>")
        // Missing semantic header must be reported as unsupported.
        ambiguous.setEnabled(true); try await wait { ambiguous.status == "Stories layout not recognized" }
        _ = secondWeb.url; ambiguous.shutdown()
    }
    func testForeignAndInsecureOriginsNeverFilter() async throws {
        for origin in ["https://instagram.com.evil.invalid", "http://www.instagram.com", "https://www.instagram.com:444"] {
            let (web, filter) = try await harness(body: "<header><span>Sponsored</span></header>", origin: origin)
            filter.setEnabled(true)
            try await wait { filter.status == "Filter applies to the stories viewer only" }
            XCTAssertFalse(filter.isBlocked); _ = web.url; filter.shutdown()
        }
    }

    func testLateViewerHeaderIsRetriedWithoutNavigation() async throws {
        let (web, filter) = try await harness(body: "<div id='loading'>Loading fictional viewer</div>")
        defer { filter.shutdown() }
        filter.setEnabled(true)
        try await wait { filter.status == "Stories layout not recognized" }
        _ = try await web.evaluateJavaScript("document.querySelector('main').insertAdjacentHTML('afterbegin','<header><span>Sponsored</span></header>');")
        try await wait { filter.isBlocked }
    }

    func testImportedListChecksVisibleAuthorAndLeavesUnknownVisible() async throws {
        let (web, filter) = try await harness()
        defer { filter.shutdown() }
        filter.updateAccounts(["friend"]); filter.setEnabled(true)
        try await wait { filter.status == "Stories filter active" }
        // Ad/recycled owner changes without changing the route's followed account.
        _ = try await web.evaluateJavaScript("const a=document.querySelector('header a');a.href='/advertiser/';a.textContent='advertiser';")
        try await wait { filter.isBlocked }
        XCTAssertEqual(filter.unknownCount, 0)
        _ = try await web.evaluateJavaScript("document.querySelector('header').innerHTML='<span>Loading</span>';")
        try await wait { filter.status == "Story author not recognized · left visible" }
        XCTAssertEqual(filter.unknownCount, 1)
        _ = try await web.evaluateJavaScript(#"document.querySelector('header').innerHTML="<a href='/friend/'>friend</a>";"#)
        try await wait { !filter.isBlocked }
    }

    func testUnmarkedViewerAuthorBeforeMediaAndAdBadge() async throws {
        let (web, filter) = try await harness(path: "/stories/friend/", body: "<div><a href='/friend/'>friend</a><span id='badge'>Today</span></div><img width='300' height='300' alt='Fictional media'><p><a href='/stranger/'>stranger</a> Sponsored</p>")
        defer { filter.shutdown() }
        filter.updateAccounts(["friend"]); filter.setEnabled(true)
        try await wait { filter.status == "Stories filter active" }
        _ = try await web.evaluateJavaScript("document.getElementById('badge').textContent='Sponsored';")
        try await wait { filter.isBlocked }
        _ = try await web.evaluateJavaScript("document.getElementById('badge').textContent='Today';")
        try await wait { !filter.isBlocked }
    }

    func testUnsupportedViewerStaysVisibleAndRecoversAfterHydration() async throws {
        let (web, filter) = try await harness(path: "/stories/", body: "<div>Loading fictional story</div>")
        defer { filter.shutdown() }
        filter.updateAccounts(["friend"]); filter.setEnabled(true)
        try await wait { filter.status == "Story author not recognized · left visible" }
        _ = try await web.evaluateJavaScript(#"document.querySelector('main').insertAdjacentHTML('afterbegin',"<header><a href='/friend/'>friend</a></header>");"#)
        try await wait { filter.status == "Stories filter active" }
        _ = try await web.evaluateJavaScript("document.querySelector('main').remove();")
        try await wait { filter.status == "Story author not recognized · left visible" }
        filter.setEnabled(false)
        XCTAssertFalse(filter.isBlocked)
    }

    func testConflictingAuthorsAreUnrecognizedRatherThanSponsored() async throws {
        let (web, filter) = try await harness(body: "<header><a href='/friend/'>friend</a></header><div><a href='/advertiser/'>advertiser</a></div><img width='300' height='300' alt='Fictional media'>")
        defer { filter.shutdown(); _ = web.url }
        filter.updateAccounts(["friend"]); filter.setEnabled(true)
        try await wait { filter.status == "Story author not recognized · left visible" }
        XCTAssertFalse(filter.isBlocked)
    }

    func testFollowedProfileDisplayNameAndAvatarAreNotClassifiedAsAds() async throws {
        for author in ["<a href='/friend/'>Fictional Display Name ✓</a>", "<a href='/friend/' aria-label='Profile picture'><img width='32' height='32' alt='Fictional avatar'></a>"] {
            let (web, filter) = try await harness(body: "<header>\(author)</header><p>Fictional story</p>")
            filter.updateAccounts(["friend"]); filter.setEnabled(true)
            try await wait { filter.status == "Stories filter active" }
            XCTAssertFalse(filter.isBlocked); XCTAssertEqual(filter.blockExplanation, "")
            _ = web.url; filter.shutdown()
        }
    }

    func testUnknownViewerDoesNotBlockFriendsOrClaimSponsorship() async throws {
        let (web, filter) = try await harness(body: "<header>Loading</header><header>Another panel</header><p>Fictional story</p>")
        defer { filter.shutdown(); _ = web.url }
        filter.updateAccounts(["friend"]); filter.setEnabled(true)
        try await wait { filter.status == "Story author not recognized · left visible" }
        XCTAssertFalse(filter.isBlocked); XCTAssertEqual(filter.blockExplanation, "")
        XCTAssertEqual(filter.hiddenCount, 0); XCTAssertEqual(filter.unknownCount, 1)
    }

    func testSponsoredAndOutsideListHaveSeparateReasons() async throws {
        let (web, filter) = try await harness()
        defer { filter.shutdown() }
        filter.updateAccounts(["friend"]); filter.setEnabled(true)
        try await wait { filter.status == "Stories filter active" }
        _ = try await web.evaluateJavaScript("document.getElementById('badge').textContent='Sponsored';")
        try await wait { filter.status == "Sponsored story hidden" }
        XCTAssertTrue(filter.blockExplanation.contains("sponsored label"))
        _ = try await web.evaluateJavaScript("document.getElementById('badge').textContent='Today';const a=document.querySelector('header a');a.href='/other/';a.textContent='Fictional Advertiser';")
        try await wait { filter.status == "Story from a non-imported account hidden" }
        XCTAssertFalse(filter.blockExplanation.lowercased().contains("sponsored"))
    }

}
