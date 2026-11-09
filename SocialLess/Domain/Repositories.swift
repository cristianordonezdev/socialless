import Foundation

@MainActor
protocol SessionRepository: AnyObject {
    func loadSessions() throws -> [SessionSummary]
    func loadCheckpoint() throws -> SessionCheckpoint?
    func checkpoint(_ checkpoint: SessionCheckpoint) throws
    /// Atomically upsert by session ID and remove its checkpoint.
    func finish(_ session: SessionSummary) throws
    func deleteAll() throws
}

@MainActor
protocol SettingsRepository: AnyObject {
    func load() throws -> AppSettings
    func save(_ settings: AppSettings) throws
}

