import Foundation
import Observation
import WebKit

@MainActor @Observable final class StoriesFilterController {
    static let world = WKContentWorld.world(name: "SocialLess.Stories")
    private(set) var isBlocked = false
    private(set) var blockExplanation = ""
    private(set) var enabled = false
    private(set) var status = "Stories filter off"
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
        webView.configuration.userContentController.add(StoriesFilterRelay { [weak self] in self?.receive($0) },
                                                        contentWorld: Self.world, name: "storiesHealth")
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
        self.enabled = enabled
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
        guard !stopped else { return }
        failed = false; apply()
    }
    func pageFailed() { failed = true; apply() }
    func shutdown() {
        guard !stopped else { return }
        isBlocked = false
        stopped = true; revision = UUID().uuidString
        enabled = false; accounts = []; hiddenCount = 0; unknownCount = 0; status = "Stories filter off"
        observation?.invalidate(); observation = nil
        restore()
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "storiesHealth", contentWorld: Self.world)
    }
    private func restore() {
        webView?.evaluateJavaScript("globalThis.sociallessStories?.dispose(); delete globalThis.sociallessStories;",
                                    in: nil, in: Self.world, completionHandler: nil)
    }
    private func apply() {
        guard !stopped else { return }
        revision = UUID().uuidString
        guard enabled, !paused, !failed else {
            isBlocked = false
            hiddenCount = 0; unknownCount = 0
            restore()
            status = paused ? "Stories filter paused" : failed ? "Waiting for stories" : "Stories filter off"
            return
        }
        guard let webView, webView.url != nil else { status = "Waiting for stories"; return }
        if status == "Stories filter off" || status == "Stories filter paused" || status == "Waiting for stories" {
            status = "Checking stories layout"
        }
        let token = revision
        do {
            guard let url = Bundle.main.url(forResource: "stories_filter", withExtension: "js") else { throw FilterRuleError.invalidBundle }
            let runtime = try String(contentsOf: url, encoding: .utf8)
            let data = try JSONSerialization.data(withJSONObject: ["accounts": accounts, "revision": token, "owner": owner,
                                                                  "marker": "data-socialless-stories-" + UUID().uuidString.lowercased()])
            let source = "(function(config){\n" + runtime + "\n})(" + String(decoding: data, as: UTF8.self) + ");"
            webView.evaluateJavaScript(source, in: nil, in: Self.world) { [weak self] result in
                guard let self, !self.stopped, self.revision == token else { return }
                if case .failure = result { self.isBlocked = false; self.restore(); self.status = "Stories filter unavailable" }
            }
        } catch { isBlocked = false; restore(); status = "Stories filter unavailable" }
    }
    private func receive(_ message: WKScriptMessage) {
        guard !stopped, enabled, !paused, !failed, message.frameInfo.isMainFrame, message.webView === webView,
              let body = message.body as? [String: Any], body["revision"] as? String == revision,
              let state = body["state"] as? String,
              let hidden = body["hidden"] as? Int, (0...500).contains(hidden),
              let unknown = body["unknown"] as? Int, (0...500).contains(unknown) else { return }
        let titles = ["active": "Stories filter active", "blockedSponsored": "Sponsored story hidden",
                      "blockedAccount": "Story from a non-imported account hidden",
                      "unrecognized": "Story author not recognized · left visible",
                      "outside": "Filter applies to the stories viewer only",
                      "unsupported": "Stories layout not recognized",
                      "failed": "Stories filter unavailable", "styleBlocked": "Website prevented hiding stories"]
        guard let title = titles[state] else { return }
        isBlocked = state == "blockedSponsored" || state == "blockedAccount"
        blockExplanation = state == "blockedSponsored" ? "A sponsored label was recognized in this story's author area." :
            state == "blockedAccount" ? "This story's identified account is outside your imported following list." : ""
        status = title
        hiddenCount = hidden; unknownCount = unknown
    }
}

@MainActor private final class StoriesFilterRelay: NSObject, WKScriptMessageHandler {
    let receive: (WKScriptMessage) -> Void
    init(_ receive: @escaping (WKScriptMessage) -> Void) { self.receive = receive }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) { receive(message) }
}
