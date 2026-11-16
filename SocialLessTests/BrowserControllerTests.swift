import XCTest
import WebKit
@testable import SocialLess

final class BrowserControllerTests: XCTestCase {
    @MainActor func testWebsiteVideoPolicyPreparesDynamicVideosAndRejectsUnrequestedPlay() async throws {
        let controller = BrowserController(configuration: try SessionConfiguration(platform: .instagram, intent: .checkFriends, duration: 300, mode: .website), canNavigate: { true })
        defer { controller.shutdown() }
        XCTAssertTrue(controller.webView.configuration.allowsInlineMediaPlayback)
        XCTAssertEqual(controller.webView.configuration.mediaTypesRequiringUserActionForPlayback, .all)
        XCTAssertFalse(controller.webView.configuration.preferences.isElementFullscreenEnabled)
        try await loadLocalWebsite(controller, platform: .instagram)
        _ = try await controller.webView.evaluateJavaScript("document.body.insertAdjacentHTML('beforeend', '<video id=video autoplay></video>');")
        try await Task.sleep(for: .milliseconds(100))
        let prepared = try await controller.webView.evaluateJavaScript("document.getElementById('video').playsInline && !document.getElementById('video').autoplay") as? Bool
        XCTAssertEqual(prepared, true)
        let world = WKContentWorld.world(name: "SocialLess.Media")
        let blocked: Bool = try await withCheckedThrowingContinuation { continuation in
            controller.webView.evaluateJavaScript("""
        (()=>{ const v=document.getElementById('video'); let pauses=0; v.pause=()=>pauses++;
            v.dispatchEvent(new Event('play'));
            v.dispatchEvent(new Event('touchmove',{bubbles:true}));
            v.dispatchEvent(new MouseEvent('click',{bubbles:true}));
            v.dispatchEvent(new Event('play')); return pauses===2; })()
        """, in: nil, in: world) { result in
                switch result {
                case .success(let value): continuation.resume(returning: value as? Bool == true)
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
        controller.setPaused(true); controller.setPaused(false)
        XCTAssertTrue(controller.webView.configuration.userContentController.userScripts.contains { $0.source == BrowserController.deliberateVideoPlayback })
        XCTAssertEqual(blocked, true, "Scroll and synthetic clicks must not authorize playback")
    }

    @MainActor func testRejectedFeedBatchUnloadsDocumentAndRetryKeepsFilterEnabled() async throws {
        let controller = BrowserController(configuration: try SessionConfiguration(platform: .instagram, intent: .checkFriends, duration: 300, mode: .website), canNavigate: { true })
        defer { controller.shutdown() }
        try await loadLocalWebsite(controller, platform: .instagram)
        let feed = try XCTUnwrap(controller.followingFeed)
        feed.updateAccounts(["friend"]); feed.setEnabled(true)
        try await Task.sleep(for: .milliseconds(100))
        _ = try await controller.webView.evaluateJavaScript("document.body.insertAdjacentHTML('beforeend','<main><article id=rejected>Unknown</article></main>');")
        for _ in 0..<50 where !feed.reachedEnd { try await Task.sleep(for: .milliseconds(50)) }
        XCTAssertTrue(feed.reachedEnd)
        for _ in 0..<50 {
            if (try? await controller.webView.evaluateJavaScript("document.body.innerHTML === ''")) as? Bool == true { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        let empty = try await controller.webView.evaluateJavaScript("document.body.innerHTML === ''") as? Bool
        XCTAssertEqual(empty, true)
        XCTAssertFalse(controller.webView.isUserInteractionEnabled)
        // Keep this test offline while checking retry intent and terminal gating.
        controller.webView.navigationDelegate = nil
        feed.retryFeed()
        XCTAssertFalse(feed.reachedEnd); XCTAssertTrue(feed.enabled)
        controller.shutdown(); controller.retryFeed()
        XCTAssertFalse(feed.enabled)
    }

    @MainActor private final class FrameProbe: NSObject, WKNavigationDelegate {
        let controller: BrowserController
        var canceledSubframes = 0
        var allowedSubframes = 0
        init(controller: BrowserController) { self.controller = controller }
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
            controller.webView(webView, decidePolicyFor: action) { policy in
                if action.targetFrame?.isMainFrame == false {
                    if policy == .cancel { self.canceledSubframes += 1 }
                    if policy == .allow { self.allowedSubframes += 1 }
                }
                decisionHandler(policy)
            }
        }
    }

    @MainActor func testBlockedEmbeddedFrameDoesNotReplaceTheMainPageWithAnError() async throws {
        let configuration = try SessionConfiguration(platform: .instagram, intent: .checkFriends, duration: 300, mode: .website)
        let controller = BrowserController(configuration: configuration, canNavigate: { true })
        defer { controller.shutdown() }
        // Seed synthetic first-party HTML without a network request, then exercise the real delegate.
        controller.webView.navigationDelegate = nil
        controller.webView.loadHTMLString("<html><body><h1 id='fixture'>Synthetic page</h1></body></html>", baseURL: configuration.platform.homeURL)
        for _ in 0..<50 {
            if (try? await controller.webView.evaluateJavaScript("document.getElementById('fixture') !== null")) as? Bool == true { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        let probe = FrameProbe(controller: controller)
        controller.webView.navigationDelegate = probe
        _ = try await controller.webView.evaluateJavaScript("""
        (() => { const frame = document.createElement('iframe');
        frame.src = 'https://outside.invalid/embedded'; document.body.appendChild(frame); })()
        """)
        for _ in 0..<50 where probe.canceledSubframes == 0 { try await Task.sleep(for: .milliseconds(100)) }
        XCTAssertEqual(probe.canceledSubframes, 1, "The cross-origin embedded navigation must still be canceled")
        XCTAssertNil(controller.message, "A rejected subframe must not turn the whole website into an error screen")
        let pageIntact = try await controller.webView.evaluateJavaScript("document.getElementById('fixture') !== null") as? Bool
        XCTAssertEqual(pageIntact, true)
    }

    @MainActor private func loadLocalWebsite(_ controller: BrowserController, platform: SocialPlatform) async throws {
        controller.webView.loadHTMLString("<html><body><h1 id='fixture'>Synthetic page</h1></body></html>", baseURL: platform.homeURL)
        for _ in 0..<50 {
            if !controller.loading,
               (try? await controller.webView.evaluateJavaScript("document.getElementById('fixture') !== null")) as? Bool == true { return }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTFail("The synthetic first-party page did not finish loading")
    }

    @MainActor func testBlankAndSrcdocFramesLoadForAllPlatformsWithoutHidingTheMainPage() async throws {
        for platform in SocialPlatform.allCases {
            let configuration = try SessionConfiguration(platform: platform, intent: .checkFriends, duration: 300, mode: .website)
            let controller = BrowserController(configuration: configuration, canNavigate: { true })
            defer { controller.shutdown() }
            try await loadLocalWebsite(controller, platform: platform)
            let probe = FrameProbe(controller: controller)
            controller.webView.navigationDelegate = probe
            _ = try await controller.webView.evaluateJavaScript("""
            (() => {
                const empty = document.createElement('iframe'); empty.src = 'about:blank'; document.body.appendChild(empty);
                const inline = document.createElement('iframe'); inline.srcdoc = '<p>Inline fixture</p>'; document.body.appendChild(inline);
            })()
            """)
            for _ in 0..<50 where probe.allowedSubframes < 2 { try await Task.sleep(for: .milliseconds(100)) }
            XCTAssertGreaterThanOrEqual(probe.allowedSubframes, 2)
            XCTAssertEqual(probe.canceledSubframes, 0)
            XCTAssertNil(controller.message)
            XCTAssertNil(controller.navigationNotice)
            XCTAssertFalse(controller.loading)
        }
    }

    @MainActor func testRejectedTopLevelLinkPreservesCommittedPageAndShowsDismissibleNotice() async throws {
        let controller = BrowserController(configuration: try SessionConfiguration(platform: .instagram, intent: .checkFriends, duration: 300, mode: .website), canNavigate: { true })
        defer { controller.shutdown() }
        try await loadLocalWebsite(controller, platform: .instagram)
        controller.webView.load(URLRequest(url: try XCTUnwrap(URL(string: "https://outside.invalid/"))))
        for _ in 0..<50 where controller.navigationNotice == nil { try await Task.sleep(for: .milliseconds(100)) }
        XCTAssertNotNil(controller.navigationNotice)
        XCTAssertNil(controller.message)
        let intact = try await controller.webView.evaluateJavaScript("document.getElementById('fixture') !== null") as? Bool
        XCTAssertEqual(intact, true)
        controller.dismissNavigationNotice()
        XCTAssertNil(controller.navigationNotice)
        // New-window links also remain blocked, with the current page usable.
        _ = try await controller.webView.evaluateJavaScript("""
        (() => { const link = document.createElement('a'); link.href = 'https://instagram.com/';
        link.target = '_blank'; document.body.appendChild(link); link.click(); })()
        """)
        for _ in 0..<50 where controller.navigationNotice == nil { try await Task.sleep(for: .milliseconds(100)) }
        XCTAssertNotNil(controller.navigationNotice)
        XCTAssertNil(controller.message)
        XCTAssertEqual(controller.webView.url?.host, "www.instagram.com")
        // After a content-process loss there is no usable committed page to preserve.
        controller.webViewWebContentProcessDidTerminate(controller.webView)
        let processFailure = controller.message
        controller.webView.load(URLRequest(url: try XCTUnwrap(URL(string: "https://outside.invalid/"))))
        for _ in 0..<50 where controller.message == processFailure { try await Task.sleep(for: .milliseconds(50)) }
        XCTAssertNotNil(controller.message)
        XCTAssertNotEqual(controller.message, processFailure)
        XCTAssertNil(controller.navigationNotice)
    }

    @MainActor func testWebKitActuallyInvokesForeignOriginBlock() async throws {
        let configuration = try SessionConfiguration(platform: .instagram, intent: .checkFriends, duration: 300, mode: .website)
        let controller = BrowserController(configuration: configuration, canNavigate: { true })
        defer { controller.shutdown() }
        // Reserved invalid domain: the policy must cancel before network access.
        controller.webView.load(URLRequest(url: try XCTUnwrap(URL(string: "https://outside.invalid/"))))
        for _ in 0..<50 {
            if controller.message != nil { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertNotNil(controller.message, "A real WKNavigationDelegate dispatch must enforce the policy")
        XCTAssertFalse(controller.loading)
    }

    @MainActor func testDemoLoadsAllBundledFixturesWithoutPersistentWebsiteStore() async throws {
        for platform in SocialPlatform.allCases {
            let configuration = try SessionConfiguration(platform: platform, intent: .checkFriends, duration: 300, mode: .demo)
            let controller = BrowserController(configuration: configuration, canNavigate: { true })
            controller.loadHome()
            for _ in 0..<50 {
                if !controller.loading { break }
                try await Task.sleep(for: .milliseconds(100))
            }
            XCTAssertNil(controller.message)
            XCTAssertFalse(controller.loading)
            XCTAssertFalse(controller.webView.configuration.websiteDataStore.isPersistent)
            let title = try await controller.webView.evaluateJavaScript("document.title") as? String
            XCTAssertEqual(title, "SocialLess offline demo")
            controller.shutdown()
            XCTAssertFalse(controller.webView.isUserInteractionEnabled)
        }
    }

    @MainActor func testTerminalSessionCannotLoadOrRetry() async throws {
        let configuration = try SessionConfiguration(platform: .instagram, intent: .checkFriends, duration: 300, mode: .demo)
        let controller = BrowserController(configuration: configuration, canNavigate: { false })
        controller.loadHome()
        XCTAssertNil(controller.webView.url)
        XCTAssertFalse(controller.loading)
        controller.shutdown(); controller.loadHome()
        XCTAssertFalse(controller.webView.isUserInteractionEnabled)
    }
}
