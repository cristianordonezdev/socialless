import Foundation
import Observation

@MainActor @Observable
final class SessionEngine {
    enum State: Equatable { case idle, active, paused, completed(SessionSummary) }
    private(set) var state: State = .idle
    private(set) var elapsed: TimeInterval = 0
    private(set) var configuration: SessionConfiguration?
    private(set) var persistenceFailed = false
    private let clock: any SessionClocking
    private let time: any TimeProviding
    private let repository: any SessionRepository
    private var sessionID = UUID()
    private var startedAt = Date.distantPast
    private var lastCheckpoint: TimeInterval = -1
    private var keepHistory = true

    init(clock: any SessionClocking, time: any TimeProviding, repository: any SessionRepository) {
        self.clock = clock; self.time = time; self.repository = repository
    }
    var remaining: TimeInterval { max(0, (configuration?.duration ?? 0) - elapsed) }
    var isWarning: Bool { isRunning && remaining <= 60 && remaining > 0 }
    var isRunning: Bool { state == .active || state == .paused }

    func start(_ configuration: SessionConfiguration, keepHistory: Bool) throws {
        guard state == .idle else { throw SessionError.sessionAlreadyStarted }
        sessionID = UUID(); startedAt = time.wallNow; elapsed = 0
        self.configuration = configuration; self.keepHistory = keepHistory
        persistenceFailed = false; lastCheckpoint = -1
        if keepHistory {
            do { try repository.checkpoint(makeCheckpoint()) }
            catch { self.configuration = nil; throw error }
        }
        clock.start()
        state = .active
    }

    func tick() {
        guard state == .active else { return }
        elapsed = min(configuration?.duration ?? 0, clock.elapsedSeconds())
        if remaining <= 0 { finish(reason: .timeLimitReached); return }
        if elapsed - lastCheckpoint >= 1 { saveCheckpoint() }
    }

    func setSceneActive(_ active: Bool) {
        if active, state == .paused {
            clock.resume(); state = .active
        } else if !active, state == .active {
            tick()
            guard state == .active else { return }
            clock.pause(); state = .paused
            saveCheckpoint()
        }
    }

    func finish(reason: SessionEndReason) {
        guard isRunning else { return }
        elapsed = min(configuration?.duration ?? 0, clock.stop())
        let finalReason: SessionEndReason = remaining <= 0 ? .timeLimitReached : reason
        let summary = makeCheckpoint().summary(reason: finalReason, endedAt: time.wallNow)
        // Terminal state is set before persistence, so storage failure cannot extend browsing.
        state = .completed(summary)
        saveCompletion(summary)
    }

    func retryPersistence() {
        if case .completed(let summary) = state { saveCompletion(summary) }
        else if isRunning { saveCheckpoint() }
    }

    func reset() {
        guard !isRunning, !persistenceFailed else { return }
        state = .idle; configuration = nil; elapsed = 0
    }

    @discardableResult
    func recoverInterruptedSession() throws -> SessionSummary? {
        guard state == .idle, let checkpoint = try repository.loadCheckpoint() else { return nil }
        let summary = checkpoint.summary(reason: .appTerminated)
        try repository.finish(summary)
        return summary
    }

    private func makeCheckpoint() -> SessionCheckpoint {
        precondition(configuration != nil)
        return SessionCheckpoint(id: sessionID, platform: configuration!.platform, intent: configuration!.intent,
                                 mode: configuration!.mode, startedAt: startedAt, measuredAt: time.wallNow,
                                 elapsed: elapsed, limit: configuration!.duration)
    }
    private func saveCheckpoint() {
        guard keepHistory else { return }
        do { try repository.checkpoint(makeCheckpoint()); persistenceFailed = false; lastCheckpoint = elapsed }
        catch { persistenceFailed = true }
    }
    private func saveCompletion(_ summary: SessionSummary) {
        guard keepHistory else { return }
        do { try repository.finish(summary); persistenceFailed = false }
        catch { persistenceFailed = true }
    }
}

