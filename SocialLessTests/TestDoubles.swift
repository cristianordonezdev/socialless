import Foundation
@testable import SocialLess

@MainActor
final class FakeTime: TimeProviding {
    var monotonicNow: TimeInterval = 0
    var wallNow = Date(timeIntervalSince1970: 1_800_000_000)
    func advance(_ seconds: TimeInterval) { monotonicNow += seconds; wallNow += seconds }
}

@MainActor
final class MemoryRepository: SessionRepository {
    var sessions: [UUID: SessionSummary] = [:]
    var pending: SessionCheckpoint?
    var finishCalls = 0
    var shouldFail = false
    enum Failure: Error { case storage }
    func loadSessions() throws -> [SessionSummary] { Array(sessions.values) }
    func loadCheckpoint() throws -> SessionCheckpoint? { pending }
    func checkpoint(_ checkpoint: SessionCheckpoint) throws {
        if shouldFail { throw Failure.storage }
        pending = checkpoint
    }
    func finish(_ session: SessionSummary) throws {
        finishCalls += 1
        if shouldFail { throw Failure.storage }
        if sessions[session.id] == nil { sessions[session.id] = session }
        if pending?.id == session.id { pending = nil }
    }
    func deleteAll() throws { sessions = [:]; pending = nil }
}

@MainActor
final class MemorySettingsRepository: SettingsRepository {
    var value = AppSettings()
    var saveCount = 0
    func load() throws -> AppSettings { value }
    func save(_ settings: AppSettings) throws { value = settings; saveCount += 1 }
}

