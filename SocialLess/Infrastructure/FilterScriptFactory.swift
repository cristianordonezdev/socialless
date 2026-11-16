import Foundation
import WebKit

enum FilterScriptFactory {
    @MainActor static let world = WKContentWorld.world(name: "SocialLess.Filters")
    static let handlerName = "sociallessFilterHealth"

    static func source(ruleSet: FilterRuleSet, preferences: FilterPreferences, paused: Bool = false,
                       revision: String = "fixture", checking: Bool = false, checkingRuleID: String? = nil, bundle: Bundle = .main) throws -> String {
        // Revalidate even injected registries. No arbitrary CSS or script can enter a rule.
        let validated = try FilterRuleRegistry.decode(JSONEncoder().encode(ruleSet), platform: ruleSet.platform, mode: ruleSet.scope)
        guard let url = bundle.url(forResource: "filter_engine", withExtension: "js") else { throw FilterRuleError.invalidBundle }
        let runtime = try String(contentsOf: url, encoding: .utf8)
        let payload: [String: Any] = [
            "domain": validated.platform.domain, "mode": validated.scope.rawValue,
            "enabled": preferences.enabled && validated.isAvailable && !checking,
            "probeOnly": checking && checkingRuleID != nil, "checking": checking, "paused": paused, "revision": revision,
            "automaticCheck": preferences.remembers(validated) && !checking,
            "protectedSegments": FilterRuleRegistry.protectedSegments,
            "rules": validated.rules.filter { rule in
                checking ? (checkingRuleID.map { rule.id == $0 } ?? !rule.requiresIndividualCheck) : preferences.isEnabled(rule)
            }.map {
                ["id": $0.id, "path": $0.pathPrefix, "exact": $0.kind != .hideAnchorByPath,
                 "navigationLabel": $0.kind == .hideInstagramReelsNavigation ? "Reels" : $0.kind == .hideInstagramExploreNavigation ? "Explore" : ""] as [String: Any]
            },
            "marker": "data-socialless-" + UUID().uuidString.lowercased()
        ]
        let json = String(decoding: try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]), as: UTF8.self)
        return "(function(config) {\n" + runtime + "\n})(" + json + ");"
    }
}
