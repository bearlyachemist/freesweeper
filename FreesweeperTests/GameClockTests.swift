import Testing
@testable import Freesweeper

struct GameClockTests {
    @Test func countsOnlyWhileRunning() {
        let t0 = ContinuousClock.now
        var clock = GameClock()
        #expect(!clock.isRunning)
        clock.start(at: t0)
        clock.pause(at: t0 + .seconds(3))
        #expect(clock.elapsed(at: t0 + .seconds(10)) == .seconds(3))
        clock.start(at: t0 + .seconds(10))
        #expect(clock.isRunning)
        #expect(clock.elapsed(at: t0 + .seconds(12)) == .seconds(5))
    }

    @Test func startingTwiceKeepsTheFirstStart() {
        let t0 = ContinuousClock.now
        var clock = GameClock()
        clock.start(at: t0)
        clock.start(at: t0 + .seconds(5))
        #expect(clock.elapsed(at: t0 + .seconds(6)) == .seconds(6))
    }

    @Test func resumesFromSavedTimeAndResets() {
        var clock = GameClock(elapsed: .seconds(42))
        #expect(clock.elapsed() == .seconds(42))
        clock.reset()
        #expect(clock.elapsed() == .zero)
        #expect(!clock.isRunning)
    }

    @Test func durationSeconds() {
        #expect(Duration.milliseconds(1_500).seconds == 1.5)
        #expect(Duration.seconds(90).seconds == 90)
    }
}
