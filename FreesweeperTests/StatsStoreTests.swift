import Foundation
import Testing
import SweeperKit
@testable import Freesweeper

@MainActor
struct StatsStoreTests {
    let small = StatsMode(difficulty: Difficulty(width: 12, height: 12, mines: 18), noGuessing: nil)
    let large = StatsMode(difficulty: Difficulty(width: 36, height: 36, mines: 160), noGuessing: nil)

    @Test func winsBuildStreaksAndTimes() {
        let store = StatsStore(defaults: makeDefaults())
        store.record(won: true, time: 40, mode: small)
        store.record(won: true, time: 20, mode: small)
        let stats = store.stats(for: small)
        #expect(stats.played == 2 && stats.won == 2)
        #expect(stats.currentStreak == 2 && stats.bestStreak == 2)
        #expect(stats.bestTime == 20)
        #expect(stats.averageTime == 30)
        #expect(stats.winRate == 1)
        #expect(store.overall == Streak(current: 2, best: 2))
    }

    @Test func lossEndsCurrentStreaksButKeepsBests() {
        let store = StatsStore(defaults: makeDefaults())
        store.record(won: true, time: 10, mode: small)
        store.record(won: true, time: 10, mode: small)
        store.record(won: false, time: 5, mode: small)
        let stats = store.stats(for: small)
        #expect(stats.currentStreak == 0 && stats.bestStreak == 2)
        #expect(stats.averageTime == 10, "Losses don't count toward the average")
        #expect(stats.winRate == 2.0 / 3)
        #expect(store.overall == Streak(current: 0, best: 2))
    }

    @Test func overallStreakSpansModes() {
        let store = StatsStore(defaults: makeDefaults())
        store.record(won: true, time: 10, mode: small)
        store.record(won: true, time: 99, mode: large)
        #expect(store.overall.current == 2)
        #expect(store.stats(for: small).currentStreak == 1)
        #expect(store.stats(for: large).currentStreak == 1)
    }

    @Test func noGuessingIsItsOwnMode() {
        let store = StatsStore(defaults: makeDefaults())
        let noGuess = StatsMode(difficulty: Difficulty(width: 12, height: 12, mines: 18), noGuessing: .hard)
        store.record(won: true, time: 10, mode: noGuess)
        #expect(store.stats(for: noGuess).won == 1)
        #expect(store.stats(for: small).won == 0)
    }

    @Test func resultCarriesBeforeAndAfter() {
        let store = StatsStore(defaults: makeDefaults())
        let first = store.record(won: true, time: 30, mode: small)
        #expect(first.previousBest == nil && first.isNewBest)
        #expect(first.modeStreakBefore == 0 && first.modeStreakAfter == 1)

        let slower = store.record(won: true, time: 45, mode: small)
        #expect(slower.previousBest == 30 && !slower.isNewBest)
        #expect(slower.overallStreakBefore == 1 && slower.overallStreakAfter == 2)

        let faster = store.record(won: true, time: 25, mode: small)
        #expect(faster.isNewBest)

        let loss = store.record(won: false, time: 1, mode: small)
        #expect(!loss.isNewBest && loss.modeStreakAfter == 0)
    }

    @Test func resetClearsOneModeAndKeepsOverall() {
        let store = StatsStore(defaults: makeDefaults())
        store.record(won: true, time: 10, mode: small)
        store.record(won: true, time: 10, mode: large)
        store.reset(small)
        #expect(store.stats(for: small) == ModeStats())
        #expect(store.stats(for: large).won == 1)
        #expect(store.overall.current == 2)
    }

    @Test func persistsAcrossLaunches() {
        let defaults = makeDefaults()
        StatsStore(defaults: defaults).record(won: true, time: 12, mode: small)
        let reloaded = StatsStore(defaults: defaults)
        #expect(reloaded.stats(for: small).bestTime == 12)
        #expect(reloaded.overall.current == 1)
    }

    @Test func corruptDataStartsFresh() {
        let defaults = makeDefaults()
        defaults.set(Data("not json".utf8), forKey: "stats")
        let store = StatsStore(defaults: defaults)
        #expect(store.modes.isEmpty)
        #expect(store.overall == Streak())
    }
}
