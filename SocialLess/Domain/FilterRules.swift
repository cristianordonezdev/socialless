import Foundation

enum FilterRuleKind: String, Codable { case hideAnchorByPath, hideAnchorByExactPath, hideInstagramReelsNavigation, hideInstagramExploreNavigation }

struct FilterRule: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let enabledByDefault: Bool
    let kind: FilterRuleKind
    var pathPrefix: String
    var requiresIndividualCheck: Bool { kind == .hideInstagramExploreNavigation }
}

struct FilterRuleSet: Codable, Equatable {
    let platform: SocialPlatform
    let scope: BrowsingMode
    let schemaVersion: Int
    let ruleSetVersion: String
    let availability: AvailabilityStatus
    var rules: [FilterRule]
    var isAvailable: Bool { availability != .unavailable && !rules.isEmpty }
    var requiresPageCheck: Bool { scope == .website && isAvailable }
    var supportsRemembering: Bool { platform == .instagram && requiresPageCheck }
}

struct FilterPreferences: Codable, Equatable {
    // Opt in separately for each platform and demo/website experience.
    var enabled = false
    var ruleOverrides: [String: Bool] = [:]
    // Missing in older settings: remembering is a separate, version-specific opt-in.
    var rememberedRuleSetVersion: String?
    // Explicit remembered consent for additional, independently checked rules.
    var approvedRuleIDs: Set<String>?
    func isEnabled(_ rule: FilterRule) -> Bool { ruleOverrides[rule.id] ?? rule.enabledByDefault }

    func remembers(_ ruleSet: FilterRuleSet) -> Bool {
        ruleSet.supportsRemembering && rememberedRuleSetVersion == ruleSet.ruleSetVersion
    }

    func forNewWebsiteSession(ruleSet: FilterRuleSet?) -> FilterPreferences {
        guard let ruleSet, remembers(ruleSet) else { return FilterPreferences() }
        return self
    }
}

enum FilterHealth: String {
    case unavailable, loading, checking, ready, off, active, noMatches, unsupportedLayout, partial, styleBlocked, paused, failed
    var title: String {
        switch self {
        case .unavailable: return "Basic timed browsing only"
        case .loading: return "Waiting for page"
        case .checking: return "Checking navigation links"
        case .ready: return "Compatible navigation link found"
        case .off: return "Filters off"
        case .active: return "Filters active"
        case .noMatches: return "No matching navigation links"
        case .unsupportedLayout: return "Navigation links found · layout unsupported"
        case .partial: return "Some navigation filters could not apply"
        case .styleBlocked: return "Website prevented hiding links"
        case .paused: return "Filters paused"
        case .failed: return "Filters unavailable"
        }
    }
}

protocol PlatformRulesProviding {
    func rules(for platform: SocialPlatform, mode: BrowsingMode) throws -> FilterRuleSet
}

enum FilterRuleError: Error { case invalidBundle, invalidRuleSet, invalidPath }

struct FilterRuleRegistry: PlatformRulesProviding {
    let bundle: Bundle
    init(bundle: Bundle = .main) { self.bundle = bundle }

    // Also supplied to JavaScript: protected paths never become filtering targets.
    static let protectedSegments = ["account", "accounts", "login", "signin", "sign-in", "logout",
                                    "auth", "oauth", "consent", "checkpoint", "challenge", "recover",
                                    "recovery", "password", "privacy", "settings", "help", "support"]

    func rules(for platform: SocialPlatform, mode: BrowsingMode) throws -> FilterRuleSet {
        let name = platform.rawValue + (mode == .demo ? "_demo_rules" : "_rules")
        guard let url = bundle.url(forResource: name, withExtension: "json") else { throw FilterRuleError.invalidBundle }
        return try Self.decode(Data(contentsOf: url), platform: platform, mode: mode)
    }

    static func decode(_ data: Data, platform: SocialPlatform, mode: BrowsingMode) throws -> FilterRuleSet {
        var result = try JSONDecoder().decode(FilterRuleSet.self, from: data)
        guard result.platform == platform, result.scope == mode, result.schemaVersion == 1,
              result.ruleSetVersion.range(of: #"^\d+\.\d+\.\d+$"#, options: .regularExpression) != nil,
              result.rules.count <= 20,
              Set(result.rules.map(\.id)).count == result.rules.count,
              result.availability != .unavailable || result.rules.isEmpty else { throw FilterRuleError.invalidRuleSet }
        for index in result.rules.indices {
            let rule = result.rules[index]
            guard rule.id.range(of: #"^[a-z][a-z0-9-]{0,63}$"#, options: .regularExpression) != nil,
                  !rule.title.isEmpty, rule.title.count <= 80 else { throw FilterRuleError.invalidRuleSet }
            result.rules[index].pathPrefix = try normalizePath(rule.pathPrefix)
            if rule.kind == .hideInstagramReelsNavigation || rule.kind == .hideInstagramExploreNavigation {
                let destination = rule.kind == .hideInstagramReelsNavigation ? "/reels" : "/explore"
                guard platform == .instagram, mode == .website, result.rules[index].pathPrefix == destination else {
                    throw FilterRuleError.invalidRuleSet
                }
            }
        }
        return result
    }

    static func normalizePath(_ path: String) throws -> String {
        guard path.count <= 128,
              path.range(of: #"^/[A-Za-z0-9_-]+(?:/[A-Za-z0-9_-]+)*/?$"#, options: .regularExpression) != nil,
              !path.lowercased().split(separator: "/").contains(where: { protectedSegments.contains(String($0)) }) else {
            throw FilterRuleError.invalidPath
        }
        return path.hasSuffix("/") ? String(path.dropLast()) : path
    }
}
