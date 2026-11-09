import XCTest
@testable import SocialLess

final class SessionTimerTests: XCTestCase {
    @MainActor private func setup(duration: Double = 300, history: Bool = true) throws -> (SessionEngine, FakeTime, MemoryRepository) {
        let time = FakeTime(), repository = MemoryRepository()
        let engine = SessionEngine(clock: MonotonicSessionClock(time: time), time: time, repository: repository)
        try engine.start(SessionConfiguration(platform: .instagram, intent: .checkFriends, duration: duration, mode: .demo), keepHistory: history)
        return (engine, time, repository)
    }

    @MainActor func testWarningAndExactExpirationBoundaries() async throws {
        let (engine, time, repository) = try setup(duration: 120)
        time.advance(59); engine.tick()
        XCTAssertEqual(engine.remaining, 61); XCTAssertFalse(engine.isWarning)
        time.advance(1); engine.tick()
        XCTAssertEqual(engine.remaining, 60); XCTAssertTrue(engine.isWarning)
        time.advance(60); engine.tick()
        guard case .completed(let summary) = engine.state else { return XCTFail("Must be terminal at exact limit") }
        XCTAssertEqual(summary.activeDurationSeconds, 120)
        XCTAssertEqual(summary.endReason, .timeLimitReached)
        XCTAssertFalse(engine.isWarning)
        XCTAssertEqual(repository.sessions.count, 1)
    }

    @MainActor func testBackgroundAndInactiveTimeDoesNotCount() async throws {
        let (engine, time, _) = try setup()
        time.advance(17); engine.setSceneActive(false)
        engine.setSceneActive(false)
        time.advance(3_600); engine.tick()
        XCTAssertEqual(engine.elapsed, 17); XCTAssertEqual(engine.state, .paused)
        engine.setSceneActive(true); engine.setSceneActive(true)
        time.advance(13); engine.tick()
        XCTAssertEqual(engine.elapsed, 30)
        XCTAssertEqual(engine.remaining, 270)
    }

    @MainActor func testWallClockChangesDoNotAffectDuration() async throws {
        let (engine, time, _) = try setup()
        time.wallNow += 86_400
        time.monotonicNow += 12
        engine.tick()
        time.wallNow -= 172_800
        engine.tick()
        XCTAssertEqual(engine.elapsed, 12)
        XCTAssertEqual(engine.remaining, 288)
    }

    @MainActor func testDelayedTickClampsAtLimitAndCompletionIsSavedOnce() async throws {
        let (engine, time, repository) = try setup()
        time.advance(900); engine.tick()
        engine.finish(reason: .userEnded); engine.tick(); engine.setSceneActive(true)
        XCTAssertEqual(repository.finishCalls, 1)
        XCTAssertEqual(repository.sessions.values.first?.activeDurationSeconds, 300)
        XCTAssertEqual(repository.sessions.values.first?.endReason, .timeLimitReached)
    }

    @MainActor func testCloseAtBoundaryStillRecordsExpiration() async throws {
        let (engine, time, repository) = try setup()
        time.advance(300); engine.finish(reason: .userEnded)
        XCTAssertEqual(repository.sessions.values.first?.endReason, .timeLimitReached)
        XCTAssertFalse(engine.isRunning)
    }

    @MainActor func testEarlyCloseAndNewSessionRequireReset() async throws {
        let (engine, time, repository) = try setup()
        time.advance(23.5); engine.finish(reason: .userEnded)
        let configuration = try SessionConfiguration(platform: .facebook, intent: .replyToMessages, duration: 300, mode: .demo)
        XCTAssertThrowsError(try engine.start(configuration, keepHistory: true))
        XCTAssertEqual(repository.sessions.values.first?.activeDurationSeconds, 23.5)
        engine.reset()
        try engine.start(configuration, keepHistory: true)
        XCTAssertEqual(engine.elapsed, 0)
        XCTAssertEqual(engine.state, .active)
    }

    @MainActor func testRecoveryUsesLastMeasuredCheckpointAndIsIdempotent() async throws {
        let (engine, time, repository) = try setup()
        time.advance(27); engine.tick()
        time.advance(5_000)
        let nextEngine = SessionEngine(clock: MonotonicSessionClock(time: time), time: time, repository: repository)
        let recovered = try XCTUnwrap(nextEngine.recoverInterruptedSession())
        XCTAssertEqual(recovered.activeDurationSeconds, 27)
        XCTAssertEqual(recovered.endReason, .appTerminated)
        XCTAssertEqual(recovered.endedAt, recovered.startedAt.addingTimeInterval(27))
        XCTAssertNil(try nextEngine.recoverInterruptedSession())
        XCTAssertEqual(repository.sessions.count, 1)
        XCTAssertEqual(nextEngine.state, .idle)
    }

    @MainActor func testStorageFailureCannotKeepBrowserActiveAndCanBeRetried() async throws {
        let (engine, time, repository) = try setup()
        repository.shouldFail = true
        time.advance(300); engine.tick()
        XCTAssertFalse(engine.isRunning); XCTAssertTrue(engine.persistenceFailed)
        engine.reset()
        guard case .completed = engine.state else { return XCTFail("Must remain terminal until saved") }
        repository.shouldFail = false; engine.retryPersistence()
        XCTAssertFalse(engine.persistenceFailed)
        XCTAssertEqual(repository.sessions.count, 1)
        engine.reset(); XCTAssertEqual(engine.state, .idle)
    }

    @MainActor func testFailedInitialCheckpointDoesNotStartSession() async throws {
        let time = FakeTime(), repository = MemoryRepository()
        repository.shouldFail = true
        let engine = SessionEngine(clock: MonotonicSessionClock(time: time), time: time, repository: repository)
        XCTAssertThrowsError(try engine.start(SessionConfiguration(platform: .instagram, intent: .checkFriends, duration: 300, mode: .demo), keepHistory: true))
        XCTAssertEqual(engine.state, .idle); XCTAssertNil(engine.configuration)
    }

    @MainActor func testHistoryOptOutStoresNothing() async throws {
        let (engine, time, repository) = try setup(history: false)
        XCTAssertNil(repository.pending)
        time.advance(10); engine.tick(); engine.finish(reason: .userEnded)
        XCTAssertNil(repository.pending); XCTAssertTrue(repository.sessions.isEmpty)
    }

    @MainActor func testCancelBeforeStartDoesNotPersist() async {
        let time = FakeTime(), repository = MemoryRepository()
        let engine = SessionEngine(clock: MonotonicSessionClock(time: time), time: time, repository: repository)
        engine.finish(reason: .userEnded); engine.reset()
        XCTAssertEqual(engine.state, .idle); XCTAssertTrue(repository.sessions.isEmpty)
    }

    func testRejectsInvalidDurations() {
        for duration in [0.0, -1, .infinity, -.infinity, .nan, 1801] {
            XCTAssertThrowsError(try SessionConfiguration(platform: .instagram, intent: .checkFriends, duration: duration, mode: .demo))
        }
        for minutes in SessionConfiguration.allowedMinutes {
            XCTAssertNoThrow(try SessionConfiguration(platform: .instagram, intent: .checkFriends, duration: Double(minutes * 60), mode: .demo))
        }
    }
}

