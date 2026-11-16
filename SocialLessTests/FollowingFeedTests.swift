import XCTest
import WebKit
@testable import SocialLess

@MainActor final class FollowingFeedTests: XCTestCase {
    private final class Loader: NSObject, WKNavigationDelegate {
        var finished = false
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { finished = true }
    }
    private enum Failure: Error { case timeout }
    private func wait(_ condition: @MainActor () async throws -> Bool) async throws {
        for _ in 0..<100 {
            if try await condition() { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTFail("Synthetic feed condition timed out"); throw Failure.timeout
    }
    private func post(_ id: String, _ name: String) -> String {
        "<article id='\(id)'><header><a href='/\(name)/'>\(name)</a></header><p>Fictional update</p><a href='/p/fixture_\(id)/'><time>Today</time></a></article>"
    }
    private func harness(extra: String = "", base: String = "https://www.instagram.com/", css: String = "'unsafe-inline'") async throws -> (WKWebView, FollowingFeedController) {
        let config = WKWebViewConfiguration(); config.websiteDataStore = .nonPersistent()
        let web = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: config)
        let filter = FollowingFeedController(webView: web)
        filter.updateAccounts(["friend"])
        let loader = Loader(); web.navigationDelegate = loader
        let html = "<html><head><meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'none'; style-src \(css)\"></head><body><main>" + post("friend", "friend") + post("other", "other") + extra + "</main></body></html>"
        web.loadHTMLString(html, baseURL: URL(string: base))
        try await wait { loader.finished }; web.navigationDelegate = nil
        filter.pageLoaded()
        return (web, filter)
    }
    private func hidden(_ id: String, _ web: WKWebView) async throws -> Bool {
        try await web.evaluateJavaScript("getComputedStyle(document.getElementById('\(id)')).visibility === 'hidden'") as? Bool == true
    }
    func testOptInAuthorFilteringAndExactRestoration() async throws {
        let (web, filter) = try await harness()
        defer { filter.shutdown() }
        let original = try await web.evaluateJavaScript("document.body.innerHTML") as? String
        XCTAssertFalse(filter.enabled)
        filter.setEnabled(true)
        try await wait { filter.hiddenCount == 1 }
        let friendHidden = try await hidden("friend", web), otherHidden = try await hidden("other", web)
        XCTAssertFalse(friendHidden); XCTAssertTrue(otherHidden)
        filter.setEnabled(false)
        try await wait { try await !self.hidden("other", web) }
        let restored = try await web.evaluateJavaScript("document.body.innerHTML") as? String
        XCTAssertEqual(restored, original)
    }
    func testUnconfirmedAuthorsAreHiddenInStrictImportedMode() async throws {
        let ambiguous = post("ambiguous", "other").replacingOccurrences(of: "</header>", with: "<a href='/friend/'>friend</a></header>")
        let missing = "<article id='missing'><p>No recognizable author</p></article>"
        let foreign = post("foreign", "other").replacingOccurrences(of: "href='/other/'", with: "href='https://instagram.com.evil.invalid/other/'")
        let caption = post("caption", "other").replacingOccurrences(of: "<header>", with: "<div>").replacingOccurrences(of: "</header>", with: "</div>")
        let (web, filter) = try await harness(extra: ambiguous + missing + foreign + caption)
        defer { filter.shutdown() }; filter.setEnabled(true)
        try await wait { filter.unknownCount == 4 }
        XCTAssertEqual(filter.hiddenCount, 5)
        for id in ["ambiguous", "missing", "foreign", "caption"] {
            let value = try await hidden(id, web); XCTAssertTrue(value)
        }
    }
    func testMutationRecycledAuthorPauseReplacementFailureAndTerminalState() async throws {
        let (web, filter) = try await harness()
        filter.setEnabled(true); try await wait { filter.hiddenCount == 1 }
        _ = try await web.evaluateJavaScript("const a=document.querySelector('#other header a');a.href='/friend/';a.textContent='friend';")
        try await wait { filter.hiddenCount == 0 }
        _ = try await web.evaluateJavaScript("document.querySelector('#other header a').href='/other/';document.querySelector('#other header a').textContent='other';")
        try await wait { filter.hiddenCount == 1 }
        filter.setPaused(true); try await wait { try await !self.hidden("other", web) }
        filter.setPaused(false); try await wait { filter.hiddenCount == 1 }
        filter.updateAccounts(["friend", "other"])
        XCTAssertFalse(filter.enabled); try await wait { try await !self.hidden("other", web) }
        filter.updateAccounts(["friend"]); filter.setEnabled(true); try await wait { filter.hiddenCount == 1 }
        filter.pageFailed(); try await wait { try await !self.hidden("other", web) }
        filter.pageLoaded(); try await wait { filter.hiddenCount == 1 }
        filter.shutdown(); filter.setEnabled(true); filter.pageLoaded(); filter.setPaused(false)
        try await wait { try await !self.hidden("other", web) }
        XCTAssertFalse(filter.enabled); XCTAssertEqual(filter.status, "Feed filter off")
    }
    func testAuthAndOtherRoutesNeverFilterAndSPAHomeRecovers() async throws {
        for base in ["https://instagram.com/accounts/login/", "https://instagram.com/direct/inbox/", "https://instagram.com/other/", "https://instagram.com.evil.invalid/", "http://instagram.com/"] {
            let (web, filter) = try await harness(base: base)
            filter.setEnabled(true); try await wait { filter.status == "Filter applies to the home feed only" }
            let value = try await hidden("other", web); XCTAssertFalse(value)
            filter.shutdown()
        }
        let (web, filter) = try await harness(); defer { filter.shutdown() }
        filter.setEnabled(true); try await wait { filter.hiddenCount == 1 }
        _ = try await web.evaluateJavaScript("history.pushState({}, '', '/accounts/login/');")
        try await wait { try await !self.hidden("other", web) }
        _ = try await web.evaluateJavaScript("history.replaceState({}, '', '/');")
        try await wait { filter.hiddenCount == 1 }
        filter.updateAccounts([]); filter.setEnabled(true)
        XCTAssertFalse(filter.enabled); try await wait { try await !self.hidden("other", web) }
    }
    func testCSSBlockAndWorkLimitRestoreInsteadOfClaimingSuccess() async throws {
        let (web, filter) = try await harness(css: "'none'")
        filter.setEnabled(true); try await wait { filter.status == "Website prevented hiding posts" }
        let value = try await hidden("other", web); XCTAssertFalse(value); filter.shutdown()
        let (largeWeb, largeFilter) = try await harness(extra: String(repeating: "<article>Unknown</article>", count: 501))
        largeFilter.setEnabled(true); try await wait { largeFilter.status == "Feed filter unavailable" }
        let restored = try await hidden("other", largeWeb); XCTAssertFalse(restored); largeFilter.shutdown()
    }
    func testUnmarkedAuthorAreaAndSponsoredCardsWithoutTimestampAreFilteredAndRestored() async throws {
        let media = "<img width='300' height='300' alt='Fictional media'>"
        func card(_ id: String, _ name: String, badge: String = "") -> String {
            "<article id='\(id)'><div><a href='/\(name)/'>\(name)</a>\(badge)</div>\(media)<p>Fictional caption</p></article>"
        }
        let extra = card("plain-friend", "friend") + card("plain-other", "other") +
            card("ad", "friend", badge: "<span>Sponsored</span>") +
            card("spanish-ad", "other", badge: "<span>Publicidad</span>") +
            "<article id='caption-only'>\(media)<div><a href='/other/'>other</a><span>Sponsored</span></div></article>" +
            "<article id='collaboration'><div><a href='/other/'>other</a><a href='/friend/'>friend</a></div>\(media)</article>"
        let (web, filter) = try await harness(extra: extra)
        defer { filter.shutdown() }
        let original = try await web.evaluateJavaScript("document.body.innerHTML") as? String
        filter.setEnabled(true)
        try await wait { filter.hiddenCount == 6 && filter.unknownCount == 2 }
        for id in ["other", "plain-other", "ad", "spanish-ad", "caption-only", "collaboration"] {
            let value = try await hidden(id, web); XCTAssertTrue(value, id)
        }
        for id in ["friend", "plain-friend"] {
            let value = try await hidden(id, web); XCTAssertFalse(value, id)
        }
        filter.setEnabled(false)
        try await wait { try await !self.hidden("ad", web) }
        let restored = try await web.evaluateJavaScript("document.body.innerHTML") as? String
        XCTAssertEqual(restored, original)
    }

    func testProfileNamedSponsoredAndCaptionLabelsAreNotAdsAndHiddenMediaStaysStable() async throws {
        let media = "<img width='300' height='300' alt='Fictional media'>"
        let extra = "<article id='named'><div><a href='/sponsored/'><span>sponsored</span></a></div>\(media)</article>" +
            "<article id='caption-label'><header><a href='/friend/'>friend</a></header>\(media)<p><span>Sponsored</span></p></article>" +
            "<article id='before-caption'><div><a href='/friend/'>friend</a></div><p><span>Sponsored</span></p>\(media)</article>" +
            "<article id='plain'><div><a href='/other/'>other</a></div>\(media)</article>" +
            post("no-time", "other").replacingOccurrences(of: "<time>Today</time>", with: "Today")
        let (web, filter) = try await harness(extra: extra)
        defer { filter.shutdown() }
        filter.updateAccounts(["friend", "sponsored"]); filter.setEnabled(true)
        try await wait { filter.hiddenCount == 3 }
        for _ in 0..<3 {
            _ = try await web.evaluateJavaScript("document.querySelector('#friend p').textContent += '.';")
            try await Task.sleep(for: .milliseconds(450))
            XCTAssertEqual(filter.hiddenCount, 3)
            let stillHidden = try await hidden("plain", web); XCTAssertTrue(stillHidden)
        }
        for id in ["named", "caption-label", "before-caption"] {
            let value = try await hidden(id, web); XCTAssertFalse(value, id)
        }
        _ = try await web.evaluateJavaScript("const a=document.querySelector('#plain a');a.href='/friend/';a.textContent='friend';")
        try await wait { filter.hiddenCount == 2 }
        let restored = try await hidden("plain", web); XCTAssertFalse(restored)
    }

    func testUnknownOnlyStatusDistinguishesMissingAuthorsFromNoPosts() async throws {
        let (web, filter) = try await harness()
        defer { filter.shutdown() }
        _ = try await web.evaluateJavaScript("document.querySelectorAll('header').forEach(n=>n.remove());")
        filter.setEnabled(true)
        try await wait { filter.status == "Unrecognized posts hidden" }
        XCTAssertEqual(filter.unknownCount, 2); XCTAssertEqual(filter.hiddenCount, 2)
        _ = try await web.evaluateJavaScript("document.querySelector('main').innerHTML='';")
        try await wait { filter.status == "No compatible feed posts found" }
        XCTAssertEqual(filter.unknownCount, 0)
    }

    func testFilteringCollapsesCardsOnceAndDoesNotRewriteMarkersOnUnrelatedMutations() async throws {
        let media = "<img width='300' height='300' alt='Fictional media'>"
        let cards = (0..<8).map { index in
            "<article id='card-\(index)' style='height:350px'><div><a href='/other/'>other</a></div>" +
            (index == 7 ? "<img width='300' style='height:80%' alt='Fictional responsive media'>" : media) + "</article>"
        }.joined()
        let (web, filter) = try await harness(extra: cards)
        defer { filter.shutdown() }
        _ = try await web.evaluateJavaScript("window.scrollTo(0, 400);")
        try await wait { try await web.evaluateJavaScript("window.scrollY") as? Int == 400 }
        let baseline = try await web.evaluateJavaScript("JSON.stringify([document.documentElement.scrollHeight, document.getElementById('card-7').getBoundingClientRect().top, window.scrollY])") as? String
        filter.setEnabled(true)
        try await wait { filter.hiddenCount == 9 }
        let filtered = try await web.evaluateJavaScript("JSON.stringify([document.documentElement.scrollHeight, document.getElementById('card-7').getBoundingClientRect().top, window.scrollY])") as? String
        XCTAssertNotEqual(filtered, baseline, "Filtering must remove the hidden cards from the feed layout")
        let collapsed = try await web.evaluateJavaScript("document.getElementById('card-7').getBoundingClientRect().height") as? Double
        XCTAssertEqual(collapsed, 0)
        let settled = try await web.evaluateJavaScript("document.documentElement.scrollHeight") as? Int
        _ = try await web.evaluateJavaScript("window.markerWrites=0; window.probe=new MutationObserver(records=>{window.markerWrites+=records.filter(r=>r.attributeName?.startsWith('data-socialless-following-')).length;}); probe.observe(document.body,{subtree:true,attributes:true});")
        for _ in 0..<3 {
            _ = try await web.evaluateJavaScript("document.querySelector('#friend p').textContent+='.';")
            try await Task.sleep(for: .milliseconds(450))
        }
        let writes = try await web.evaluateJavaScript("window.markerWrites") as? Int
        XCTAssertEqual(writes, 0, "Stable classifications must not unhide/re-hide cards")
        let settledAfterMutations = try await web.evaluateJavaScript("document.documentElement.scrollHeight") as? Int
        XCTAssertEqual(settled, settledAfterMutations)
        let beforeRefresh = try await web.evaluateJavaScript("document.documentElement.scrollHeight") as? Int
        filter.pageLoaded(); filter.pageLoaded(); filter.setPaused(false)
        try await Task.sleep(for: .milliseconds(450))
        let afterRefresh = try await web.evaluateJavaScript("document.documentElement.scrollHeight") as? Int
        let refreshWrites = try await web.evaluateJavaScript("window.markerWrites") as? Int
        XCTAssertEqual(beforeRefresh, afterRefresh); XCTAssertEqual(refreshWrites, 0)
        _ = try await web.evaluateJavaScript("window.probe.disconnect();")
        filter.setEnabled(false)
        try await wait { try await !self.hidden("card-7", web) }
    }

    func testHiddenCardBlocksDelegatedClicksAndFocusWithoutCancelingScrollGestures() async throws {
        let (web, filter) = try await harness()
        defer { filter.shutdown() }
        _ = try await web.evaluateJavaScript("document.getElementById('friend').setAttribute('inert','existing'); window.activations=0; window.siteClick=()=>window.activations++; document.addEventListener('click',window.siteClick);")
        let original = try await web.evaluateJavaScript("document.body.innerHTML") as? String
        filter.setEnabled(true)
        try await wait { filter.hiddenCount == 1 }
        let results = try await web.evaluateJavaScript("""
            (()=>{
                const card=document.getElementById('other'), link=card.querySelector('a');
                link.focus();
                const focusBlocked=document.activeElement!==link;
                const r=card.getBoundingClientRect(), options={bubbles:true,cancelable:true,clientX:r.left+2,clientY:r.top+2};
                // Hidden descendants must never reach delegated activation handlers.
                const click=new MouseEvent('click',options); link.dispatchEvent(click);
                const pointer=new PointerEvent('pointerdown',options); link.dispatchEvent(pointer);
                return [focusBlocked,click.defaultPrevented,!pointer.defaultPrevented,window.activations===0,card.inert];
            })()
            """) as? [Bool]
        XCTAssertEqual(results, [true, true, true, true, true])
        filter.setEnabled(false)
        try await wait { try await !self.hidden("other", web) }
        let restored = try await web.evaluateJavaScript("document.body.innerHTML") as? String
        XCTAssertEqual(restored, original)
        _ = try await web.evaluateJavaScript("document.getElementById('other').querySelector('a').dispatchEvent(new MouseEvent('click',{bubbles:true,cancelable:true}));")
        let activations = try await web.evaluateJavaScript("window.activations") as? Int
        XCTAssertEqual(activations, 1)
    }

    func testNewCardsAreQuarantinedBeforeClassificationAndAllowedCardsBecomeVisible() async throws {
        let (web, filter) = try await harness()
        defer { filter.shutdown() }
        filter.setEnabled(true)
        try await wait { filter.hiddenCount == 1 }
        let initiallyHidden = try await web.evaluateJavaScript("""
        (()=>{
            document.querySelector('main').insertAdjacentHTML('beforeend',
                "<article id='new-friend'><header><a href='/friend/'>friend</a></header><a href='/p/newfriend/'>Post</a></article>" +
                "<article id='new-other'><header><a href='/other/'>other</a></header><a href='/p/newother/'>Post</a></article>");
            return ['new-friend','new-other'].every(id=>getComputedStyle(document.getElementById(id)).visibility==='hidden');
        })()
        """) as? Bool
        XCTAssertEqual(initiallyHidden, true, "New cards must not flash before the observer classifies them")
        try await wait { filter.hiddenCount == 2 }
        let friendHidden = try await hidden("new-friend", web), otherHidden = try await hidden("new-other", web)
        XCTAssertFalse(friendHidden); XCTAssertTrue(otherHidden)
        filter.setEnabled(false)
        try await wait { try await !self.hidden("new-other", web) }
        let markers = try await web.evaluateJavaScript("[...document.querySelectorAll('*')].some(n=>[...n.attributes].some(a=>a.name.startsWith('data-socialless-following-')))") as? Bool
        XCTAssertEqual(markers, false)
    }

    func testRejectedBatchEndsOnceAndRetryRequiresExplicitReset() async throws {
        let (web, filter) = try await harness()
        defer { filter.shutdown() }
        var ends = 0
        filter.onExhausted = { ends += 1 }
        filter.setEnabled(true)
        try await wait { filter.hiddenCount == 1 }
        XCTAssertFalse(filter.reachedEnd)
        _ = try await web.evaluateJavaScript(#"document.querySelector('main').insertAdjacentHTML('beforeend', "<article><header><a href='/other/'>other</a></header><a href='/p/batch/'>Post</a></article>");"#)
        try await wait { filter.reachedEnd }
        XCTAssertEqual(ends, 1); XCTAssertEqual(filter.status, "No more matching posts")
        filter.pageLoaded(); filter.setPaused(true); filter.setPaused(false)
        try await Task.sleep(for: .milliseconds(600))
        XCTAssertTrue(filter.reachedEnd); XCTAssertEqual(ends, 1)
        filter.retryFeed()
        XCTAssertFalse(filter.reachedEnd); XCTAssertTrue(filter.enabled)
        filter.navigationStarted(); filter.pageLoaded()
        try await wait { filter.status != "Waiting for feed" }
        XCTAssertFalse(filter.reachedEnd)
    }

    func testBatchWaitsForAuthorHydrationAndDoesNotEndWhenAMatchingPostArrives() async throws {
        let (web, filter) = try await harness()
        defer { filter.shutdown() }
        filter.setEnabled(true)
        try await wait { filter.hiddenCount == 1 }
        _ = try await web.evaluateJavaScript(#"document.querySelector('main').insertAdjacentHTML('beforeend', "<article id='hydrating'><p>Loading</p></article>");"#)
        try await Task.sleep(for: .milliseconds(100))
        _ = try await web.evaluateJavaScript(#"document.getElementById('hydrating').innerHTML="<header><a href='/friend/'>friend</a></header><a href='/p/hydrated/'>Post</a>";"#)
        try await Task.sleep(for: .milliseconds(650))
        XCTAssertFalse(filter.reachedEnd)
        let visible = try await hidden("hydrating", web); XCTAssertFalse(visible)
        _ = try await web.evaluateJavaScript("document.querySelector('main').insertAdjacentHTML('beforeend', '<article id=cancelled>Unknown</article>');")
        filter.setEnabled(false)
        try await Task.sleep(for: .milliseconds(650))
        XCTAssertFalse(filter.reachedEnd)
    }

}
