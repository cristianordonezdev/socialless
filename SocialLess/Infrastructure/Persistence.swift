import Foundation
import SwiftData

@Model
final class StoredSession {
    @Attribute(.unique) var id: UUID
    var payload: Data
    init(id: UUID, payload: Data) { self.id = id; self.payload = payload }
}

@Model
final class StoredCheckpoint {
    @Attribute(.unique) var key: String
    var payload: Data
    init(payload: Data) { key = "active"; self.payload = payload }
}

@MainActor
final class SwiftDataSessionRepository: SessionRepository {
    let container: ModelContainer
    private let context: ModelContext
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(inMemory: Bool = false, url: URL? = nil) throws {
        let schema = Schema([StoredSession.self, StoredCheckpoint.self])
        let configuration: ModelConfiguration
        if let url {
            configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        }
        container = try ModelContainer(for: schema, configurations: [configuration])
        context = ModelContext(container)
        context.autosaveEnabled = false
    }

    func loadSessions() throws -> [SessionSummary] {
        try context.fetch(FetchDescriptor<StoredSession>())
            .map { try decoder.decode(SessionSummary.self, from: $0.payload) }
            .sorted { $0.startedAt > $1.startedAt }
    }
    func loadCheckpoint() throws -> SessionCheckpoint? {
        try context.fetch(FetchDescriptor<StoredCheckpoint>()).first.map {
            try decoder.decode(SessionCheckpoint.self, from: $0.payload)
        }
    }
    func checkpoint(_ checkpoint: SessionCheckpoint) throws {
        try transaction {
            let data = try encoder.encode(checkpoint)
            if let stored = try context.fetch(FetchDescriptor<StoredCheckpoint>()).first { stored.payload = data }
            else { context.insert(StoredCheckpoint(payload: data)) }
        }
    }
    func finish(_ session: SessionSummary) throws {
        try transaction {
            let existing = try context.fetch(FetchDescriptor<StoredSession>()).contains { $0.id == session.id }
            if !existing { context.insert(StoredSession(id: session.id, payload: try encoder.encode(session))) }
            for checkpoint in try context.fetch(FetchDescriptor<StoredCheckpoint>()) {
                if try decoder.decode(SessionCheckpoint.self, from: checkpoint.payload).id == session.id {
                    context.delete(checkpoint)
                }
            }
        }
    }
    func deleteAll() throws {
        try transaction {
            for record in try context.fetch(FetchDescriptor<StoredSession>()) { context.delete(record) }
            for record in try context.fetch(FetchDescriptor<StoredCheckpoint>()) { context.delete(record) }
        }
    }
    private func transaction(_ operation: () throws -> Void) throws {
        do { try operation(); try context.save() }
        catch { context.rollback(); throw error }
    }
}

@MainActor
final class UserDefaultsSettingsRepository: SettingsRepository {
    private let defaults: UserDefaults
    private let key = "socialless.settings.v1"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func load() throws -> AppSettings {
        guard let data = defaults.data(forKey: key) else { return AppSettings() }
        return try JSONDecoder().decode(AppSettings.self, from: data)
    }
    func save(_ settings: AppSettings) throws { defaults.set(try JSONEncoder().encode(settings), forKey: key) }
}
