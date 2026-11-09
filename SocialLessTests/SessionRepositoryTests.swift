import XCTest
@testable import SocialLess

final class SessionRepositoryTests: XCTestCase {
    @MainActor func testContainerPersistsNestedSettingsChangesImmediately() async throws {
        let settings = MemorySettingsRepository()
        let container = try AppContainer(repository: MemoryRepository(), settingsRepository: settings, time: FakeTime())
        container.settings.enabledPlatforms.remove(.instagram)
        XCTAssertFalse(settings.value.enabledPlatforms.contains(.instagram))
        container.settings.defaultMinutes[.facebook] = 20
        XCTAssertEqual(settings.value.minutes(for: .facebook), 20)
        XCTAssertEqual(settings.saveCount, 2)
        let reopened = try AppContainer(repository: MemoryRepository(), settingsRepository: settings, time: FakeTime())
        XCTAssertEqual(reopened.settings, container.settings)
    }

    private func checkpoint() -> SessionCheckpoint {
        SessionCheckpoint(id: UUID(), platform: .tiktok, intent: .quickUpdate, mode: .demo,
                          startedAt: Date(timeIntervalSince1970: 1_800_000_000), measuredAt: Date(timeIntervalSince1970: 1_800_000_042), elapsed: 42, limit: 300)
    }

    @MainActor func testSwiftDataIdempotentFinishAndAtomicCheckpointRemoval() async throws {
        let repository = try SwiftDataSessionRepository(inMemory: true)
        let pending = checkpoint()
        try repository.checkpoint(pending)
        XCTAssertEqual(try repository.loadCheckpoint(), pending)
        let summary = pending.summary(reason: .userEnded)
        try repository.finish(summary); try repository.finish(summary)
        XCTAssertEqual(try repository.loadSessions(), [summary])
        XCTAssertNil(try repository.loadCheckpoint())
        try repository.deleteAll()
        XCTAssertTrue(try repository.loadSessions().isEmpty)
    }

    @MainActor func testSwiftDataSurvivesRepositoryRecreation() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.store")
        let pending = checkpoint()
        do {
            let repository = try SwiftDataSessionRepository(url: url)
            try repository.checkpoint(pending)
        }
        let reopened = try SwiftDataSessionRepository(url: url)
        XCTAssertEqual(try reopened.loadCheckpoint(), pending)
        try reopened.finish(pending.summary(reason: .appTerminated))
        let second = try SwiftDataSessionRepository(url: url)
        XCTAssertEqual(try second.loadSessions().count, 1)
        XCTAssertNil(try second.loadCheckpoint())
    }

    @MainActor func testFinishingOldIDDoesNotRemoveNewCheckpoint() async throws {
        let repository = try SwiftDataSessionRepository(inMemory: true)
        let old = checkpoint(), current = checkpoint()
        try repository.checkpoint(current)
        try repository.finish(old.summary(reason: .appTerminated))
        XCTAssertEqual(try repository.loadCheckpoint(), current)
    }

    @MainActor func testPreferencesRoundTripAndDefaultValidation() async throws {
        let name = "socialless.tests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let repository = UserDefaultsSettingsRepository(defaults: defaults)
        XCTAssertEqual(try repository.load(), AppSettings())
        var settings = AppSettings()
        settings.keepHistory = false; settings.enabledPlatforms = [.facebook]
        settings.defaultMinutes[.facebook] = 20; settings.defaultMinutes[.instagram] = -3
        try repository.save(settings)
        let restored = try UserDefaultsSettingsRepository(defaults: defaults).load()
        XCTAssertEqual(restored, settings)
        XCTAssertEqual(restored.minutes(for: .instagram), 10)
        XCTAssertEqual(restored.minutes(for: .facebook), 20)
    }

    @MainActor func testCorruptPreferencesAreReportedInsteadOfOverwritten() async throws {
        let name = "socialless.tests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let data = Data("bad data".utf8)
        defaults.set(data, forKey: "socialless.settings.v1")
        XCTAssertThrowsError(try UserDefaultsSettingsRepository(defaults: defaults).load())
        XCTAssertEqual(defaults.data(forKey: "socialless.settings.v1"), data)
    }
}

