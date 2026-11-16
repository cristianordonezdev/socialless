import Foundation
import Observation
import WebKit

@MainActor @Observable final class FollowingFeedController {
    static let world = WKContentWorld.world(name: "SocialLess.Following")
    private(set) var reachedEnd = false
    var onExhausted: (() -> Void)?
    private(set) var enabled = false
    private(set) var status = "Feed filter off"
    private(set) var hiddenCount = 0
    private(set) var unknownCount = 0
    private var accounts: [String] = []
    private var paused = false
    private var stopped = false
    private var failed = false
    private var revision = ""
    private let owner = UUID().uuidString
    @ObservationIgnored private weak var webView: WKWebView?
    @ObservationIgnored private var observation: NSKeyValueObservation?

    init(webView: WKWebView) {
        self.webView = webView
        webView.configuration.userContentController.add(FollowingFeedRelay { [weak self] in self?.receive($0) },
                                                        contentWorld: Self.world, name: "followingHealth")
        observation = webView.observe(\.url, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in self?.pageLoaded() }
        }
    }
    func updateAccounts(_ accounts: [String]) {
        guard !stopped else { return }
        self.accounts = accounts
        // A replacement or deletion must never silently broaden a running filter.
        enabled = false
        apply()
    }
    func setEnabled(_ enabled: Bool) {
        guard !stopped else { return }
        self.enabled = enabled && !accounts.isEmpty
        apply()
    }
    func setPaused(_ paused: Bool) {
        guard !stopped, self.paused != paused else { return }
        self.paused = paused; apply()
    }
    func navigationStarted() {
        guard !stopped else { return }
        failed = true; apply()
    }
    func pageLoaded() {
        guard !stopped, !reachedEnd else { return }
        failed = false; apply()
    }
    func pageFailed() { guard !reachedEnd else { return }; failed = true; apply() }
    func retryFeed() {
        guard !stopped else { return }
        reachedEnd = false; failed = false
        status = "Waiting for feed"
    }
    func shutdown() {
        guard !stopped else { return }
        onExhausted = nil
        stopped = true; revision = UUID().uuidString
        enabled = false; accounts = []; hiddenCount = 0; unknownCount = 0; status = "Feed filter off"
        observation?.invalidate(); observation = nil
        restore()
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "followingHealth", contentWorld: Self.world)
    }
    private func restore() {
        webView?.evaluateJavaScript("globalThis.sociallessFollowing?.dispose(); delete globalThis.sociallessFollowing;",
                                    in: nil, in: Self.world, completionHandler: nil)
    }
    private func apply() {
        guard !stopped, !reachedEnd else { return }
        revision = UUID().uuidString
        guard enabled, !paused, !failed else {
            hiddenCount = 0; unknownCount = 0
            restore()
            status = paused ? "Feed filter paused" : failed ? "Waiting for feed" : "Feed filter off"
            return
        }
        guard let webView, webView.url != nil else { status = "Waiting for feed"; return }
        if status == "Feed filter off" || status == "Feed filter paused" || status == "Waiting for feed" {
            status = "Checking feed layout"
        }
        let token = revision
        do {
            guard let url = Bundle.main.url(forResource: "following_feed", withExtension: "js") else { throw FilterRuleError.invalidBundle }
            let runtime = try String(contentsOf: url, encoding: .utf8)
            let data = try JSONSerialization.data(withJSONObject: ["accounts": accounts, "revision": token, "owner": owner,
                                                                  "marker": "data-socialless-following-" + UUID().uuidString.lowercased()])
            let source = "(function(config){\n" + runtime + "\n})(" + String(decoding: data, as: UTF8.self) + ");"
            webView.evaluateJavaScript(source, in: nil, in: Self.world) { [weak self] result in
                guard let self, !self.stopped, self.revision == token else { return }
                if case .failure = result { self.restore(); self.status = "Feed filter unavailable" }
            }
        } catch { restore(); status = "Feed filter unavailable" }
    }
    private func receive(_ message: WKScriptMessage) {
        guard !stopped, enabled, !paused, !failed, message.frameInfo.isMainFrame, message.webView === webView,
              let body = message.body as? [String: Any], body["revision"] as? String == revision,
              let state = body["state"] as? String,
              let hidden = body["hidden"] as? Int, (0...500).contains(hidden),
              let unknown = body["unknown"] as? Int, (0...500).contains(unknown) else { return }
        if state == "exhausted" {
            reachedEnd = true; status = "No more matching posts"
            hiddenCount = hidden; unknownCount = unknown
            revision = UUID().uuidString
            onExhausted?()
            return
        }
        let titles = ["active": "Imported-account filter active", "partial": "Unrecognized posts hidden",
                      "unsupported": "No compatible feed posts found", "outside": "Filter applies to the home feed only",
                      "failed": "Feed filter unavailable", "styleBlocked": "Website prevented hiding posts"]
        guard let title = titles[state] else { return }
        status = state == "unsupported" && unknown > 0 ? "Unrecognized posts hidden" : title
        hiddenCount = hidden; unknownCount = unknown
    }
}

@MainActor private final class FollowingFeedRelay: NSObject, WKScriptMessageHandler {
    let receive: (WKScriptMessage) -> Void
    init(_ receive: @escaping (WKScriptMessage) -> Void) { self.receive = receive }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) { receive(message) }
}
