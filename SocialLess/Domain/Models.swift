import Foundation

enum SocialPlatform: String, CaseIterable, Codable, Identifiable {
    case instagram, facebook, tiktok
    var id: String { rawValue }
    var title: String {
        switch self {
        case .instagram: return "Instagram"
        case .facebook: return "Facebook"
        case .tiktok: return "TikTok"
        }
    }
    var symbol: String {
        switch self {
        case .instagram: return "camera"
        case .facebook: return "person.2"
        case .tiktok: return "music.note"
        }
    }
    var domain: String { "\(rawValue).com" }
    var homeURL: URL { URL(string: "https://www.\(domain)/")! }
}

enum SessionIntent: String, CaseIterable, Codable, Identifiable {
    case checkFriends, replyToMessages, quickUpdate
    var id: String { rawValue }
    var title: String {
        switch self {
        case .checkFriends: return "Check friends"
        case .replyToMessages: return "Reply to someone"
        case .quickUpdate: return "Quick update"
        }
    }
    var symbol: String {
        switch self {
        case .checkFriends: return "person.2"
        case .replyToMessages: return "bubble.left.and.bubble.right"
        case .quickUpdate: return "pencil.line"
        }
    }
}

enum SessionEndReason: String, Codable {
    case userEnded, timeLimitReached, navigationFailure, appTerminated
    var title: String {
        switch self {
        case .userEnded: return "Ended intentionally"
        case .timeLimitReached: return "Time limit reached"
        case .navigationFailure: return "Browser interrupted"
        case .appTerminated: return "App interrupted"
        }
    }
}

enum BrowsingMode: String, Codable, CaseIterable, Identifiable {
    case demo, website
    var id: String { rawValue }
    var title: String { self == .demo ? "Offline demo" : "Website · experimental" }
}

enum AvailabilityStatus: String, Codable { case verified, experimental, unavailable }

struct PlatformCapability {
    let browser: AvailabilityStatus = .experimental
    let filtering: AvailabilityStatus = .unavailable
    let notes = "Basic timed browsing only. Website login, messages and following views have not been verified on iPhone. Friends-only filtering is unavailable."
}

struct SessionConfiguration: Equatable {
    static let allowedMinutes = [5, 10, 15, 20, 30]
    let platform: SocialPlatform
    let intent: SessionIntent
    let duration: TimeInterval
    let mode: BrowsingMode

    init(platform: SocialPlatform, intent: SessionIntent, duration: TimeInterval, mode: BrowsingMode) throws {
        guard duration.isFinite, duration > 0, duration <= 1_800 else { throw SessionError.invalidDuration }
        self.platform = platform
        self.intent = intent
        self.duration = duration
        self.mode = mode
    }
}

enum SessionError: LocalizedError {
    case invalidDuration, sessionAlreadyStarted
    var errorDescription: String? {
        switch self {
        case .invalidDuration: return "Choose a session length between 5 and 30 minutes."
        case .sessionAlreadyStarted: return "Finish your current session before starting another."
        }
    }
}

struct SessionSummary: Identifiable, Codable, Equatable {
    let id: UUID
    let platform: SocialPlatform
    let intent: SessionIntent
    let mode: BrowsingMode
    let startedAt: Date
    let endedAt: Date
    let activeDurationSeconds: TimeInterval
    let endReason: SessionEndReason
}

struct SessionCheckpoint: Codable, Equatable {
    let id: UUID
    let platform: SocialPlatform
    let intent: SessionIntent
    let mode: BrowsingMode
    let startedAt: Date
    let measuredAt: Date
    let elapsed: TimeInterval
    let limit: TimeInterval

    func summary(reason: SessionEndReason, endedAt: Date? = nil) -> SessionSummary {
        SessionSummary(id: id, platform: platform, intent: intent, mode: mode, startedAt: startedAt,
                       endedAt: endedAt ?? measuredAt, activeDurationSeconds: min(limit, max(0, elapsed)), endReason: reason)
    }
}

struct AppSettings: Codable, Equatable {
    var completedOnboarding = false
    var enabledPlatforms = Set(SocialPlatform.allCases)
    var defaultMinutes: [SocialPlatform: Int] = [.instagram: 10, .facebook: 10, .tiktok: 10]
    var defaultMode: BrowsingMode = .demo
    var keepHistory = true
    var weeklyGoalMinutes = 120

    func minutes(for platform: SocialPlatform) -> Int {
        let value = defaultMinutes[platform] ?? 10
        return SessionConfiguration.allowedMinutes.contains(value) ? value : 10
    }
}

enum TimeLabel {
    static func countdown(_ seconds: TimeInterval) -> String {
        let value = Int(ceil(max(0, seconds)))
        return String(format: "%02d:%02d", value / 60, value % 60)
    }
    static func duration(_ seconds: TimeInterval) -> String {
        let value = Int(max(0, seconds))
        return value < 60 ? "\(value)s" : "\(value / 60)m \(value % 60)s"
    }
}

