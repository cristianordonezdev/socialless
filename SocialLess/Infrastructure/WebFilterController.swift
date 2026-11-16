import Foundation
import Observation
import WebKit

@MainActor @Observable
final class WebFilterController {
    let ruleSet: FilterRuleSet?
    private(set) var health: FilterHealth
    private(set) var counts: [String: Int] = [:]
    private(set) var preferences: FilterPreferences
    private(set) var pageCheckPassed = false
    private(set) var checkedRuleIDs: Set<String> = []
    private(set) var ruleCheckHealth: [String: FilterHealth] = [:]
    private var probe: (id: String, revision: String)?
    private var hasRememberedChoice: Bool { ruleSet.map { preferences.remembers($0) } ?? false }
    var canEnable: Bool {
        !stopped && ruleSet?.isAvailable == true &&
        (ruleSet?.requiresPageCheck != true || pageCheckPassed || !checkedRuleIDs.isEmpty || hasRememberedChoice)
    }
    var canRemember: Bool { !stopped && ruleSet?.supportsRemembering == true && health == .active && canEnable }
    func canEnableRule(_ rule: FilterRule) -> Bool {
        guard !stopped else { return false }
        if ruleSet?.requiresPageCheck != true { return true }
        if rule.requiresIndividualCheck {
            return checkedRuleIDs.contains(rule.id) || (hasRememberedChoice && preferences.approvedRuleIDs?.contains(rule.id) == true)
        }
        return pageCheckPassed || hasRememberedChoice
    }
    @ObservationIgnored private weak var webView: WKWebView?
    @ObservationIgnored private let contentController: WKUserContentController
    @ObservationIgnored private let companionScripts: [WKUserScript]
    @ObservationIgnored private var urlObservation: NSKeyValueObservation?
    private var source: String?
    private var revision = ""
    private var paused = false
    private var stopped = false
    private var checking = false

    init(platform: SocialPlatform, mode: BrowsingMode, preferences: FilterPreferences,
         contentController: WKUserContentController, registry: any PlatformRulesProviding = FilterRuleRegistry(), companionScripts: [WKUserScript] = []) {
        self.contentController = contentController
        self.companionScripts = companionScripts
        companionScripts.forEach { contentController.addUserScript($0) }
        self.preferences = preferences
        do {
            let loaded = try registry.rules(for: platform, mode: mode)
            ruleSet = try FilterRuleRegistry.decode(JSONEncoder().encode(loaded), platform: platform, mode: mode)
            health = ruleSet?.isAvailable == true ? .loading : .unavailable
        } catch {
            ruleSet = nil
            health = .failed
        }
        guard ruleSet?.isAvailable == true else { return }
        // Only explicit consent for this catalog can request automatic, locally checked filtering.
        if ruleSet?.requiresPageCheck == true, !hasRememberedChoice { self.preferences.enabled = false }
        for rule in ruleSet?.rules ?? [] where rule.requiresIndividualCheck && !canEnableRule(rule) {
            self.preferences.ruleOverrides[rule.id] = false
        }
        let relay = FilterMessageRelay { [weak self] message in self?.receive(message) }
        contentController.add(relay, contentWorld: FilterScriptFactory.world, name: FilterScriptFactory.handlerName)
        prepareScript()
    }

    func attach(to webView: WKWebView) {
        self.webView = webView
        // WebKit observes history.pushState/replaceState too; no patching page-world JS.
        urlObservation = webView.observe(\.url, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in self?.pageLoaded() }
        }
    }

    func update(_ preferences: FilterPreferences) {
        guard !stopped else { return }
        var allowed = preferences
        if allowed.rememberedRuleSetVersion != self.preferences.rememberedRuleSetVersion,
           allowed.rememberedRuleSetVersion != nil, !canRemember {
            allowed.rememberedRuleSetVersion = self.preferences.rememberedRuleSetVersion
        }
        if !canEnable { allowed.enabled = false }
        if let ruleSet {
            let eligible = Set(ruleSet.rules.filter { canEnableRule($0) }.map(\.id))
            allowed.approvedRuleIDs = allowed.approvedRuleIDs.map { $0.intersection(eligible) }
            for rule in ruleSet.rules where !eligible.contains(rule.id) {
                allowed.ruleOverrides[rule.id] = false
            }
        }
        guard allowed != self.preferences else { return }
        self.preferences = allowed
        checking = false
        prepareScript()
        applyToCurrentDocument()
    }

    func checkPage() {
        guard !stopped, !paused, ruleSet?.requiresPageCheck == true, webView?.url != nil else { return }
        cancelProbe()
        preferences.enabled = false
        pageCheckPassed = false
        checking = true
        counts = [:]; health = .checking
        prepareScript()
        applyToCurrentDocument()
    }

    func checkRule(_ id: String) {
        guard !stopped, !paused, let ruleSet, ruleSet.requiresPageCheck,
              ruleSet.rules.contains(where: { $0.id == id && $0.requiresIndividualCheck }),
              webView?.url != nil else { return }
        cancelProbe()
        let token = UUID().uuidString
        probe = (id, token)
        ruleCheckHealth[id] = .checking
        do {
            let script = try FilterScriptFactory.source(ruleSet: ruleSet, preferences: preferences,
                                                        revision: token, checking: true, checkingRuleID: id)
            webView?.evaluateJavaScript(script, in: nil, in: FilterScriptFactory.world) { [weak self] result in
                guard let self, !self.stopped, self.probe?.revision == token else { return }
                if case .failure = result { self.ruleCheckHealth[id] = .failed; self.probe = nil }
            }
        } catch { ruleCheckHealth[id] = .failed; probe = nil }
    }

    private func cancelProbe() {
        if let probe { ruleCheckHealth[probe.id] = .off }
        probe = nil
    }

    func setPaused(_ value: Bool) {
        guard !stopped, paused != value else { return }
        paused = value
        cancelProbe()
        checking = false
        prepareScript()
        applyToCurrentDocument()
    }

    func navigationStarted() {
        guard !stopped, ruleSet?.isAvailable == true else { return }
        cancelProbe()
        // A check belongs to the current document; a late result must not authorize a new one.
        if checking { checking = false; prepareScript() }
        counts = [:]; health = .loading
    }

    func pageLoaded() {
        guard !stopped, ruleSet?.isAvailable == true else { return }
        // Reconcile a preference change made while the new document was loading.
        cancelProbe()
        applyToCurrentDocument()
    }

    func pageFailed() {
        guard !stopped, ruleSet?.isAvailable == true else { return }
        checking = false; pageCheckPassed = false
        cancelProbe(); checkedRuleIDs = []; ruleCheckHealth = [:]
        prepareScript()
        webView?.evaluateJavaScript("globalThis.sociallessFilters?.dispose(); delete globalThis.sociallessFilters;",
                                    in: nil, in: FilterScriptFactory.world, completionHandler: nil)
        counts = [:]; health = .failed
    }

    func shutdown() {
        guard !stopped else { return }
        stopped = true
        cancelProbe(); checkedRuleIDs = []; ruleCheckHealth = [:]
        urlObservation?.invalidate(); urlObservation = nil
        contentController.removeAllUserScripts()
        contentController.removeScriptMessageHandler(forName: FilterScriptFactory.handlerName, contentWorld: FilterScriptFactory.world)
        webView?.evaluateJavaScript("globalThis.sociallessFilters?.dispose(); delete globalThis.sociallessFilters;",
                                    in: nil, in: FilterScriptFactory.world, completionHandler: nil)
        counts = [:]; health = .off; source = nil; checking = false; pageCheckPassed = false
    }

    private func prepareScript() {
        guard !stopped, let ruleSet, ruleSet.isAvailable else { return }
        // Preserve browser media policy when replacing navigation-filter scripts.
        contentController.removeAllUserScripts()
        companionScripts.forEach { contentController.addUserScript($0) }
        revision = UUID().uuidString
        do {
            var effective = preferences
            effective.enabled = preferences.enabled && canEnable
            for rule in ruleSet.rules where !canEnableRule(rule) { effective.ruleOverrides[rule.id] = false }
            let script = try FilterScriptFactory.source(ruleSet: ruleSet, preferences: effective, paused: paused,
                                                        revision: revision, checking: checking)
            source = script
            contentController.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentEnd,
                                                        forMainFrameOnly: true, in: FilterScriptFactory.world))
        } catch { source = nil; health = .failed; counts = [:] }
    }

    private func applyToCurrentDocument() {
        guard !stopped, let source, let webView, webView.url != nil else { return }
        let expectedRevision = revision
        webView.evaluateJavaScript(source, in: nil, in: FilterScriptFactory.world) { [weak self] result in
            guard let self, !self.stopped, self.revision == expectedRevision else { return }
            if case .failure = result { self.pageFailed() }
        }
    }

    private func receive(_ message: WKScriptMessage) {
        guard !stopped, message.frameInfo.isMainFrame, message.webView === webView,
              let ruleSet, let body = message.body as? [String: Any],
              let state = body["state"] as? String, let health = FilterHealth(rawValue: state),
              let rawCounts = body["counts"] as? [String: Int],
              rawCounts.count <= ruleSet.rules.count,
              rawCounts.allSatisfy({ entry in ruleSet.rules.contains { $0.id == entry.key } && (0...1000).contains(entry.value) }) else { return }
        if let probe, body["revision"] as? String == probe.revision {
            ruleCheckHealth[probe.id] = health
            if health == .ready && (rawCounts[probe.id] ?? 0) > 0 { checkedRuleIDs.insert(probe.id) }
            self.probe = nil
            return
        }
        guard body["revision"] as? String == revision else { return }
        self.health = health
        counts = rawCounts
        if hasRememberedChoice {
            // This is live health only, never persisted evidence of compatibility.
            pageCheckPassed = health == .active && rawCounts.values.contains { $0 > 0 }
        }
        if checking {
            pageCheckPassed = health == .ready && rawCounts.values.contains { $0 > 0 }
            checking = false
            // Future documents never inherit the one-shot probe. Enabling is a separate user action.
            prepareScript()
        }
    }
}

// WKUserContentController retains the handler. The closure retains the owner weakly.
@MainActor private final class FilterMessageRelay: NSObject, WKScriptMessageHandler {
    let receive: (WKScriptMessage) -> Void
    init(receive: @escaping (WKScriptMessage) -> Void) { self.receive = receive }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) { receive(message) }
}
