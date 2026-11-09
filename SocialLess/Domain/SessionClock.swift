import Foundation

@MainActor
protocol TimeProviding {
    var monotonicNow: TimeInterval { get }
    var wallNow: Date { get }
}

@MainActor
final class SystemTimeProvider: TimeProviding {
    private let origin = ContinuousClock.now
    var monotonicNow: TimeInterval {
        let parts = origin.duration(to: .now).components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }
    var wallNow: Date { Date() }
}

@MainActor
protocol SessionClocking: AnyObject {
    func start()
    func pause()
    func resume()
    func elapsedSeconds() -> TimeInterval
    func stop() -> TimeInterval
}

@MainActor
final class MonotonicSessionClock: SessionClocking {
    private let time: any TimeProviding
    private var accumulated: TimeInterval = 0
    private var segmentStart: TimeInterval?
    init(time: any TimeProviding) { self.time = time }
    func start() { accumulated = 0; segmentStart = time.monotonicNow }
    func pause() {
        accumulated = elapsedSeconds()
        segmentStart = nil
    }
    func resume() {
        guard segmentStart == nil else { return }
        segmentStart = time.monotonicNow
    }
    func elapsedSeconds() -> TimeInterval {
        accumulated + (segmentStart.map { max(0, time.monotonicNow - $0) } ?? 0)
    }
    func stop() -> TimeInterval { pause(); return accumulated }
}

