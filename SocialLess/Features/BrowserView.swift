import SwiftUI
import WebKit
import UIKit

struct BrowserView: View {
    @Bindable var engine: SessionEngine
    @State private var controller: BrowserController?

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
                } else {
                    SocialWebView(controller: controller)
                        .allowsHitTesting(engine.state == .active)
                        .accessibilityIdentifier("browser.webview")
                }
                HStack {
                    Button { controller.goBack() } label: { Label("Back", systemImage: "chevron.left") }
                        .disabled(!controller.canGoBack).frame(minHeight: 44)
                    Spacer()
                    Text(engine.configuration?.mode == .demo ? "Offline sample · no real accounts" : "Experimental · no filters")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(.horizontal, 20).background(Theme.card)
            } else { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
        }
        .navigationTitle(engine.configuration?.platform.title ?? "Session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Close") { engine.finish(reason: .userEnded) }.accessibilityIdentifier("session.close")
            }
        }
        .task {
            guard controller == nil, let configuration = engine.configuration else { return }
            let sessionEngine = engine
            let browser = BrowserController(configuration: configuration) { [weak sessionEngine] in
                sessionEngine?.tick()
                return sessionEngine?.state == .active
            }
            controller = browser
            browser.loadHome()
        }
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
    func makeUIView(context: Context) -> WKWebView { controller.webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    static func dismantleUIView(_ uiView: WKWebView, coordinator: ()) {
        uiView.stopLoading()
        uiView.setAllMediaPlaybackSuspended(true)
        uiView.isUserInteractionEnabled = false
    }
}

@MainActor @Observable
final class BrowserController: NSObject, WKNavigationDelegate, WKUIDelegate {
    let webView: WKWebView
    private(set) var loading = false
    private(set) var canGoBack = false
    private(set) var message: String?
    private let configuration: SessionConfiguration
    private let canNavigate: () -> Bool
    private var stopped = false
    private var loadingDemo = false

    init(configuration: SessionConfiguration, canNavigate: @escaping () -> Bool) {
        self.configuration = configuration; self.canNavigate = canNavigate
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.websiteDataStore = configuration.mode == .demo ? .nonPersistent() : .default()
        webConfiguration.preferences.javaScriptCanOpenWindowsAutomatically = false
        webConfiguration.mediaTypesRequiringUserActionForPlayback = .all
        webConfiguration.allowsInlineMediaPlayback = false
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        super.init()
        webView.navigationDelegate = self; webView.uiDelegate = self
        webView.allowsLinkPreview = false
        webView.allowsBackForwardNavigationGestures = false
        webView.isInspectable = false
    }
    func loadHome() {
        guard !stopped, canNavigate() else { return }
        message = nil; loading = true; setPaused(false)
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
    func setPaused(_ paused: Bool) {
        webView.isUserInteractionEnabled = !paused && !stopped
        webView.setAllMediaPlaybackSuspended(paused || stopped)
    }
    func shutdown() {
        guard !stopped else { return }
        stopped = true
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
        guard navigationAction.targetFrame != nil else {
            message = "This link needs a separate window. SocialLess keeps browsing inside your timed session. Return to the home page or end this session."
            loading = false; decisionHandler(.cancel); return
        }
        guard !navigationAction.shouldPerformDownload, WebNavigationPolicy(platform: configuration.platform).allows(navigationAction.request.url) else {
            message = "This navigation is outside the supported secure website. Cross-site sign-in, external apps and downloads are unavailable. Try the home page or use the offline demo."
            loading = false; decisionHandler(.cancel); return
        }
        decisionHandler(.allow)
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping @MainActor (WKNavigationResponsePolicy) -> Void) {
        guard !stopped, canNavigate() else { decisionHandler(.cancel); return }
        let permitted = configuration.mode == .demo || WebNavigationPolicy(platform: configuration.platform).allows(navigationResponse.response.url)
        guard permitted, navigationResponse.canShowMIMEType,
              !navigationResponse.isForMainFrame || ["text/html", "application/xhtml+xml"].contains(navigationResponse.response.mimeType ?? "") else {
            message = "This page or download isn’t supported in a timed session."; loading = false
            decisionHandler(.cancel); return
        }
        decisionHandler(.allow)
    }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { loading = true }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loading = false; canGoBack = webView.canGoBack
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { fail(error) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { fail(error) }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
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
        message = "The website couldn’t load. Check your connection and retry, or end this session and choose the offline demo. Some services do not allow embedded sign-in."
    }
}
