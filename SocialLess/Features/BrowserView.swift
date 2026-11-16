import SwiftUI
import WebKit
import UIKit

struct BrowserView: View {
    @Bindable var engine: SessionEngine
    @Binding var filterPreferences: FilterPreferences
    var followingStore: FollowingListStore?
    @State private var controller: BrowserController?
    @State private var showFilters = false

    var body: some View {
        VStack(spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { sessionLabel; Spacer(); countdown }
                VStack(alignment: .leading, spacing: 12) { sessionLabel; countdown }
            }.padding(20).background(Theme.card)
            if engine.isWarning {
                Label("One minute left. Finish what you came for.", systemImage: "hourglass")
                    .font(.subheadline).padding(12).frame(maxWidth: .infinity)
                    .background(Theme.accent.opacity(0.12)).accessibilityIdentifier("session.warning")
            }
            if engine.persistenceFailed {
                HStack {
                    Text("Session history hasn’t been saved yet.").font(.caption)
                    Button("Retry") { engine.retryPersistence() }.frame(minHeight: 44)
                }.padding(.horizontal)
            }
            if let controller {
                if let notice = controller.navigationNotice {
                    HStack(alignment: .top) {
                        Text(notice).font(.footnote)
                        Spacer(minLength: 8)
                        Button { controller.dismissNavigationNotice() } label: {
                            Image(systemName: "xmark").frame(minWidth: 44, minHeight: 44)
                        }.accessibilityLabel("Dismiss link notice")
                    }.padding(.leading, 16).background(Theme.accent.opacity(0.08))
                        .accessibilityIdentifier("browser.navigationNotice")
                }
                if controller.loading { ProgressView().frame(maxWidth: .infinity).padding(8).accessibilityLabel("Loading page") }
                if let message = controller.message {
                    ScrollView {
                        ContentUnavailableView {
                            Label("This page couldn’t continue", systemImage: "network.slash")
                        } description: {
                            Text(message)
                        } actions: {
                            Button("Retry home page") { controller.loadHome() }.buttonStyle(.bordered)
                            Button("End session") { engine.finish(reason: .navigationFailure) }.frame(minHeight: 44)
                        }
                    }.accessibilityIdentifier("browser.error")
                } else if controller.followingFeed?.reachedEnd == true {
                    ContentUnavailableView {
                        Label("No more matching posts", systemImage: "checkmark.circle")
                    } description: {
                        Text("The latest loaded posts did not match your imported list. More matching posts may exist. Your session timer is still running.")
                    } actions: {
                        Button("Try again") { controller.retryFeed() }.buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("browser.retryFeed")
                        Button("End session") { engine.finish(reason: .userEnded) }.frame(minHeight: 44)
                    }.accessibilityIdentifier("browser.feedEnd")
                } else {
                    ZStack {
                        SocialWebView(controller: controller)
                            .allowsHitTesting(engine.state == .active && controller.storiesFilter?.isBlocked != true)
                            .accessibilityHidden(controller.storiesFilter?.isBlocked == true)
                            .accessibilityIdentifier("browser.webview")
                        if controller.storiesFilter?.isBlocked == true {
                            ContentUnavailableView {
                                Label("Story hidden", systemImage: "eye.slash")
                            } description: {
                                Text(controller.storiesFilter?.blockExplanation ?? "")
                            } actions: {
                                Button("Back to Instagram") { controller.loadHome() }.buttonStyle(.borderedProminent)
                                Button("Turn off story filter") { controller.storiesFilter?.setEnabled(false) }
                            }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.card)
                                .accessibilityIdentifier("browser.storyHidden")
                        }
                    }
                }
                HStack {
                    Button { controller.goBack() } label: { Label("Back", systemImage: "chevron.left") }
                        .disabled(!controller.canGoBack || controller.followingFeed?.reachedEnd == true).frame(minHeight: 44)
                    Spacer()
                    Text(engine.configuration?.mode == .demo ? "Demo · navigation links only" :
                         controller.followingFeed?.enabled == true ? "Experimental · \(controller.followingFeed?.status ?? "Feed filter")" :
                         controller.filters.ruleSet?.isAvailable == true ? "Experimental · \(controller.filters.health.title)" : "Real website · filters not active")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(.horizontal, 20).background(Theme.card)
            } else { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
        }
        .navigationTitle(engine.configuration?.platform.title ?? "Session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if controller != nil {
                    Button { showFilters = true } label: { Label("Filters", systemImage: "line.3.horizontal.decrease.circle") }
                        .accessibilityIdentifier("browser.filters")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Close") { engine.finish(reason: .userEnded) }.accessibilityIdentifier("session.close")
            }
        }
        .task {
            guard controller == nil, let configuration = engine.configuration else { return }
            let sessionEngine = engine
            let browser = BrowserController(configuration: configuration, filterPreferences: filterPreferences) { [weak sessionEngine] in
                sessionEngine?.tick()
                return sessionEngine?.state == .active
            }
            browser.followingFeed?.updateAccounts(followingStore?.list?.accounts ?? [])
            browser.storiesFilter?.updateAccounts(followingStore?.list?.accounts ?? [])
            controller = browser
            browser.loadHome()
        }
        .sheet(isPresented: $showFilters) {
            if let controller, let configuration = engine.configuration {
                NavigationStack {
                    FilterControlsView(platform: configuration.platform, mode: configuration.mode,
                                       ruleSet: controller.filters.ruleSet, preferences: $filterPreferences,
                                       health: controller.filters.health, counts: controller.filters.counts,
                                       canEnable: controller.filters.canEnable, canRemember: controller.filters.canRemember, checkPage: {
                                           filterPreferences.enabled = false
                                           controller.filters.checkPage()
                                       }, canEnableRule: { controller.filters.canEnableRule($0) },
                                       ruleCheckHealth: controller.filters.ruleCheckHealth,
                                       checkRule: { controller.filters.checkRule($0) },
                                       followingStore: followingStore, followingFeed: controller.followingFeed, storiesFilter: controller.storiesFilter)
                        .toolbar { ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showFilters = false }.accessibilityIdentifier("filters.done")
                        } }
                }
            }
        }
        .onChange(of: followingStore?.list) { _, list in
            controller?.followingFeed?.updateAccounts(list?.accounts ?? [])
            controller?.storiesFilter?.updateAccounts(list?.accounts ?? [])
        }
        .onChange(of: filterPreferences) { _, preferences in controller?.filters.update(preferences) }
        .onChange(of: engine.state) { _, state in controller?.setPaused(state != .active) }
        .onChange(of: engine.isWarning) { _, warning in
            if warning { UIAccessibility.post(notification: .announcement, argument: "One minute left. Finish what you came for.") }
        }
        .onDisappear { controller?.shutdown(); controller = nil }
    }
    private var sessionLabel: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(engine.configuration?.intent.title ?? "Your intention").font(.headline)
            Text(engine.state == .paused ? "Paused while inactive" : "A little time, on purpose").font(.caption).foregroundStyle(.secondary)
        }
    }
    private var countdown: some View {
        Text(TimeLabel.countdown(engine.remaining)).font(.system(.largeTitle, design: .rounded, weight: .medium))
            .monospacedDigit().foregroundStyle(Theme.accent)
            .accessibilityLabel("Time remaining").accessibilityValue(TimeLabel.countdown(engine.remaining))
            .accessibilityIdentifier("session.countdown")
    }
}

private struct SocialWebView: UIViewRepresentable {
    let controller: BrowserController
    func makeCoordinator() -> BrowserController { controller }
    func makeUIView(context: Context) -> WKWebView { controller.webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    static func dismantleUIView(_ uiView: WKWebView, coordinator: BrowserController) {
        // Let the empty-document replacement finish when the finite-feed screen appears.
        if coordinator.followingFeed?.reachedEnd != true { uiView.stopLoading() }
        uiView.setAllMediaPlaybackSuspended(true)
        uiView.isUserInteractionEnabled = false
    }
}

@MainActor @Observable
final class BrowserController: NSObject, WKNavigationDelegate, WKUIDelegate {
    let webView: WKWebView
    let filters: WebFilterController
    let followingFeed: FollowingFeedController?
    let storiesFilter: StoriesFilterController?
    private(set) var loading = false
    private(set) var canGoBack = false
    private(set) var message: String?
    private(set) var navigationNotice: String?
    private let configuration: SessionConfiguration
    private let canNavigate: () -> Bool
    private var stopped = false
    private var loadingDemo = false
    private var hasCommittedPage = false

    init(configuration: SessionConfiguration, filterPreferences: FilterPreferences = FilterPreferences(),
         rules: any PlatformRulesProviding = FilterRuleRegistry(), canNavigate: @escaping () -> Bool) {
        self.configuration = configuration; self.canNavigate = canNavigate
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.websiteDataStore = configuration.mode == .demo ? .nonPersistent() : .default()
        #if DEBUG
        if BrowserTestFixtures.usesInstagramPilot(configuration) { webConfiguration.websiteDataStore = .nonPersistent() }
        #endif
        webConfiguration.preferences.javaScriptCanOpenWindowsAutomatically = false
        webConfiguration.mediaTypesRequiringUserActionForPlayback = .all
        webConfiguration.allowsInlineMediaPlayback = true
        webConfiguration.preferences.isElementFullscreenEnabled = false
        let mediaScripts: [WKUserScript] = configuration.mode == .website ? [WKUserScript(
            source: Self.deliberateVideoPlayback, injectionTime: .atDocumentStart,
            forMainFrameOnly: false, in: WKContentWorld.world(name: "SocialLess.Media"))] : []
        filters = WebFilterController(platform: configuration.platform, mode: configuration.mode,
                                      preferences: filterPreferences, contentController: webConfiguration.userContentController,
                                      registry: rules, companionScripts: mediaScripts)
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        followingFeed = configuration.platform == .instagram && configuration.mode == .website
            ? FollowingFeedController(webView: webView) : nil
        storiesFilter = configuration.platform == .instagram && configuration.mode == .website
            ? StoriesFilterController(webView: webView) : nil
        super.init()
        followingFeed?.onExhausted = { [weak self] in self?.unloadExhaustedFeed() }
        webView.navigationDelegate = self; webView.uiDelegate = self
        webView.allowsLinkPreview = false
        webView.allowsBackForwardNavigationGestures = false
        webView.isInspectable = false
        filters.attach(to: webView)
    }
    // Isolated DOM policy: scrolling never grants video playback permission.
    static let deliberateVideoPlayback = """
    (() => {
        const permitted = new WeakSet();
        function prepare(video) {
            if (!video.hasAttribute('playsinline')) video.setAttribute('playsinline', '');
            if (!video.hasAttribute('webkit-playsinline')) video.setAttribute('webkit-playsinline', '');
            if (video.hasAttribute('autoplay')) video.removeAttribute('autoplay');
        }
        document.addEventListener('click', event => {
            if (!event.isTrusted) return;
            const video = event.composedPath().find(node => node instanceof HTMLVideoElement);
            if (video && !video.closest('[inert]')) permitted.add(video);
        }, true);
        document.addEventListener('play', event => {
            const video = event.target;
            if (!(video instanceof HTMLVideoElement)) return;
            prepare(video);
            if (!permitted.has(video) || video.closest('[inert]')) video.pause();
        }, true);
        document.addEventListener('pause', event => permitted.delete(event.target), true);
        document.addEventListener('ended', event => permitted.delete(event.target), true);
        const observer = new MutationObserver(records => {
            for (const record of records) {
                if (record.target instanceof HTMLVideoElement) prepare(record.target);
                for (const node of record.addedNodes) {
                    if (!(node instanceof Element)) continue;
                    if (node instanceof HTMLVideoElement) prepare(node);
                    node.querySelectorAll('video').forEach(prepare);
                }
            }
        });
        observer.observe(document, {subtree:true, childList:true, attributes:true,
            attributeFilter:['autoplay','playsinline','webkit-playsinline']});
    })();
    """

    private func unloadExhaustedFeed() {
        guard !stopped else { return }
        webView.stopLoading()
        webView.setAllMediaPlaybackSuspended(true)
        webView.isUserInteractionEnabled = false
        // Destroy the live document to stop its pagination scripts; website data stays in WebKit.
        webView.navigationDelegate = nil
        webView.loadHTMLString("", baseURL: nil)
    }
    func retryFeed() {
        guard !stopped, canNavigate(), followingFeed?.reachedEnd == true else { return }
        followingFeed?.retryFeed()
        webView.navigationDelegate = self
        webView.isUserInteractionEnabled = true
        loadHome()
    }

    func loadHome() {
        guard !stopped, canNavigate() else { return }
        message = nil; navigationNotice = nil; loading = true; setPaused(false)
        #if DEBUG
        if BrowserTestFixtures.usesInstagramPilot(configuration) {
            webView.loadHTMLString(BrowserTestFixtures.instagramUnmarkedNavigation, baseURL: configuration.platform.homeURL)
            return
        }
        #endif
        if configuration.mode == .demo {
            guard let url = Bundle.main.url(forResource: configuration.platform.rawValue + "_fixture", withExtension: "html"),
                  let html = try? String(contentsOf: url, encoding: .utf8) else {
                message = "The offline sample is missing. End this session and reinstall the app."; loading = false; return
            }
            loadingDemo = true
            webView.loadHTMLString(html, baseURL: nil)
        } else { webView.load(URLRequest(url: configuration.platform.homeURL)) }
    }
    func goBack() {
        guard !stopped, canNavigate(), webView.canGoBack else { return }
        message = nil; webView.goBack()
    }
    func dismissNavigationNotice() { navigationNotice = nil }
    func setPaused(_ paused: Bool) {
        filters.setPaused(paused || stopped)
        followingFeed?.setPaused(paused || stopped)
        storiesFilter?.setPaused(paused || stopped)
        webView.isUserInteractionEnabled = !paused && !stopped
        webView.setAllMediaPlaybackSuspended(paused || stopped)
    }
    func shutdown() {
        guard !stopped else { return }
        stopped = true
        filters.shutdown()
        followingFeed?.shutdown()
        storiesFilter?.shutdown()
        webView.stopLoading(); setPaused(true)
        webView.navigationDelegate = nil; webView.uiDelegate = nil
        webView.loadHTMLString("", baseURL: nil)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        guard !stopped, canNavigate() else { decisionHandler(.cancel); return }
        if configuration.mode == .demo {
            if loadingDemo, navigationAction.request.url?.absoluteString == "about:blank", navigationAction.targetFrame?.isMainFrame == true {
                loadingDemo = false; decisionHandler(.allow)
            } else { decisionHandler(.cancel) }
            return
        }
        let policy = WebNavigationPolicy(platform: configuration.platform)
        if navigationAction.targetFrame?.isMainFrame == false {
            // A blocked embedded document must not replace an otherwise usable main page.
            let allowed = !navigationAction.shouldPerformDownload && policy.allowsEmbeddedDocument(navigationAction.request.url)
            decisionHandler(allowed ? .allow : .cancel)
            return
        }
        guard navigationAction.targetFrame != nil else {
            if navigationAction.sourceFrame.isMainFrame {
                reportBlockedNavigation("This link needs a separate window and wasn’t opened. SocialLess keeps browsing inside your timed session.")
            }
            decisionHandler(.cancel); return
        }
        guard !navigationAction.shouldPerformDownload, policy.allows(navigationAction.request.url) else {
            reportBlockedNavigation("This link is outside the supported secure website and wasn’t opened. Cross-site sign-in, external apps and downloads are unavailable here.")
            decisionHandler(.cancel); return
        }
        decisionHandler(.allow)
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping @MainActor (WKNavigationResponsePolicy) -> Void) {
        guard !stopped, canNavigate() else { decisionHandler(.cancel); return }
        if configuration.mode == .website, !navigationResponse.isForMainFrame {
            let allowed = WebNavigationPolicy(platform: configuration.platform).allowsEmbeddedDocument(navigationResponse.response.url)
                && navigationResponse.canShowMIMEType
            decisionHandler(allowed ? .allow : .cancel)
            return
        }
        let permitted = configuration.mode == .demo || WebNavigationPolicy(platform: configuration.platform).allows(navigationResponse.response.url)
        guard permitted, navigationResponse.canShowMIMEType,
              !navigationResponse.isForMainFrame || ["text/html", "application/xhtml+xml"].contains(navigationResponse.response.mimeType ?? "") else {
            reportBlockedNavigation("This page or download isn’t supported in a timed session.")
            decisionHandler(.cancel); return
        }
        decisionHandler(.allow)
    }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        loading = true; filters.navigationStarted(); followingFeed?.navigationStarted(); storiesFilter?.navigationStarted()
    }
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        hasCommittedPage = true
        message = nil; navigationNotice = nil
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loading = false; canGoBack = webView.canGoBack
        filters.pageLoaded(); followingFeed?.pageLoaded(); storiesFilter?.pageLoaded()
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { fail(error) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { fail(error) }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        hasCommittedPage = false
        navigationNotice = nil
        filters.pageFailed(); followingFeed?.pageFailed(); storiesFilter?.pageFailed()
        loading = false; message = "The browser was interrupted. Retry the home page or end your session."
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? { nil }
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                 decisionHandler: @escaping @MainActor (WKPermissionDecision) -> Void) { decisionHandler(.deny) }
    private func fail(_ error: Error) {
        guard !stopped else { return }
        if (error as NSError).domain == NSURLErrorDomain, (error as NSError).code == NSURLErrorCancelled { return }
        loading = false
        filters.pageFailed(); followingFeed?.pageFailed(); storiesFilter?.pageFailed()
        message = "The website couldn’t load. Check your connection and retry, or end this session and choose the offline demo. Some services do not allow embedded sign-in."
    }
    private func reportBlockedNavigation(_ text: String) {
        loading = false
        if hasCommittedPage {
            navigationNotice = text
        } else {
            message = text
        }
    }
}
