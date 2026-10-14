import Foundation

/// Elapsed play time that survives pausing (app backgrounded) without counting ticks.
/// Uses the monotonic `ContinuousClock`, so changing the phone's time can't distort it.
struct GameClock {
    private var startedAt: ContinuousClock.Instant?
    private var accumulated: Duration

    init(elapsed: Duration = .zero) {
        accumulated = elapsed
    }

    var isRunning: Bool { startedAt != nil }

    func elapsed(at now: ContinuousClock.Instant = .now) -> Duration {
        accumulated + (startedAt.map { now - $0 } ?? .zero)
    }

    mutating func start(at now: ContinuousClock.Instant = .now) {
        guard startedAt == nil else { return }
        startedAt = now
    }

    mutating func pause(at now: ContinuousClock.Instant = .now) {
        accumulated = elapsed(at: now)
        startedAt = nil
    }

    mutating func reset() {
        startedAt = nil
        accumulated = .zero
    }
}

extension Duration {
    var seconds: Double {
        let parts = components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }
}
