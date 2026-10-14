import Foundation
import SweeperKit

/// A mode for stats: board size, mine count and whether it was a no-guess board.
struct StatsMode: Hashable, Codable {
    let width: Int
    let height: Int
    let mines: Int
    let noGuessing: Bool

    init(difficulty: Difficulty, noGuessing: Bool) {
        width = difficulty.width
        height = difficulty.height
        mines = difficulty.mines
        self.noGuessing = noGuessing
    }

    var key: String { "\(width)x\(height)x\(mines)" + (noGuessing ? "-noguess" : "") }

    var name: String {
        Difficulty(width: width, height: height, mines: mines).modeName + (noGuessing ? " · No Guessing" : "")
    }
}

struct ModeStats: Codable, Equatable {
    var played = 0
    var won = 0
    var currentStreak = 0
    var bestStreak = 0
    /// Seconds, to the clock's precision.
    var bestTime: Double?
    var totalWinTime: Double = 0

    var averageTime: Double? { won > 0 ? totalWinTime / Double(won) : nil }
    var winRate: Double? { played > 0 ? Double(won) / Double(played) : nil }
}

struct Streak: Codable, Equatable {
    var current = 0
    var best = 0
}

/// What just happened, with before/after values so the result card can animate the change.
struct GameResult: Identifiable, Equatable {
    let id = UUID()
    let won: Bool
    let time: Double
    let modeName: String
    let modeStreakBefore: Int
    let modeStreakAfter: Int
    let overallStreakBefore: Int
    let overallStreakAfter: Int
    /// The mode's best time before this game, if it had one.
    let previousBest: Double?
    /// Picks the card's headline so it varies from game to game.
    let flavor = Int.random(in: 0..<1_000)

    var isNewBest: Bool { won && previousBest.map { time < $0 } ?? won }
}

/// Wins, streaks and times per mode plus an overall streak, saved to UserDefaults.
@MainActor @Observable
final class StatsStore {
    private(set) var modes: [String: ModeStats]
    private(set) var overall: Streak

    private let defaults: UserDefaults
    private static let key = "stats"

    private struct Snapshot: Codable {
        var modes: [String: ModeStats]
        var overall: Streak
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let snapshot = defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(Snapshot.self, from: $0) }
        modes = snapshot?.modes ?? [:]
        overall = snapshot?.overall ?? Streak()
    }

    func stats(for mode: StatsMode) -> ModeStats {
        modes[mode.key] ?? ModeStats()
    }

    @discardableResult
    func record(won: Bool, time: Double, mode: StatsMode) -> GameResult {
        var stats = stats(for: mode)
        let before = stats
        let overallBefore = overall

        stats.played += 1
        if won {
            stats.won += 1
            stats.currentStreak += 1
            stats.bestStreak = max(stats.bestStreak, stats.currentStreak)
            stats.bestTime = min(stats.bestTime ?? time, time)
            stats.totalWinTime += time
            overall.current += 1
            overall.best = max(overall.best, overall.current)
        } else {
            stats.currentStreak = 0
            overall.current = 0
        }
        modes[mode.key] = stats
        save()

        return GameResult(
            won: won,
            time: time,
            modeName: mode.name,
            modeStreakBefore: before.currentStreak,
            modeStreakAfter: stats.currentStreak,
            overallStreakBefore: overallBefore.current,
            overallStreakAfter: overall.current,
            previousBest: before.bestTime
        )
    }

    /// Clears one mode. The overall streak is left alone.
    func reset(_ mode: StatsMode) {
        modes[mode.key] = nil
        save()
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(Snapshot(modes: modes, overall: overall)), forKey: Self.key)
    }
}
