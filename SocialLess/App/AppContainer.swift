import Foundation
import Observation

@MainActor @Observable
final class AppContainer {
    var settings: AppSettings {
        didSet { saveSettings() }
    }
    private(set) var sessions: [SessionSummary] = []
    var notice: String?
    let engine: SessionEngine
    let repository: any SessionRepository
    let settingsRepository: any SettingsRepository
    let testSessionDuration: TimeInterval?

    init(repository: any SessionRepository, settingsRepository: any SettingsRepository,
         time: any TimeProviding, testSessionDuration: TimeInterval? = nil) throws {
        self.repository = repository; self.settingsRepository = settingsRepository
        self.testSessionDuration = testSessionDuration
        settings = try settingsRepository.load()
        engine = SessionEngine(clock: MonotonicSessionClock(time: time), time: time, repository: repository)
        if try engine.recoverInterruptedSession() != nil {
            notice = "Your interrupted session was closed. Only its last saved active time was counted."
        }
        sessions = try repository.loadSessions()
    }

    static func live() throws -> AppContainer {
        var defaults = UserDefaults.standard
        var storeURL: URL?
        var fastDuration: TimeInterval?
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--uitesting") {
            let suite = "com.socialless.ui-testing"
            defaults = UserDefaults(suiteName: suite)!
            if arguments.contains("--reset-test-data") { defaults.removePersistentDomain(forName: suite) }
            let directory = URL.applicationSupportDirectory.appendingPathComponent("UITesting", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            storeURL = directory.appendingPathComponent("sessions.store")
            if arguments.contains("--fast-session") { fastDuration = 3 }
        }
        #endif
        let repository = try SwiftDataSessionRepository(url: storeURL)
        #if DEBUG
        if arguments.contains("--uitesting"), arguments.contains("--reset-test-data") { try repository.deleteAll() }
        #endif
        return try AppContainer(repository: repository, settingsRepository: UserDefaultsSettingsRepository(defaults: defaults),
                                time: SystemTimeProvider(), testSessionDuration: fastDuration)
    }

    func saveSettings() {
        do { try settingsRepository.save(settings) }
        catch { notice = "Your settings could not be saved. Please try again." }
    }
    func refreshHistory() {
        do { sessions = try repository.loadSessions() }
        catch { notice = "Your history could not be read. Existing data has been kept." }
    }
    func deleteHistory() {
        do { try repository.deleteAll(); refreshHistory() }
        catch { notice = "Your history could not be deleted. Please try again." }
    }
}

