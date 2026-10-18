import SwiftUI
import SweeperKit

/// What's shown around the game: the streak warning before a reset, the No Guessing alert and
/// the result card. Starting a new game always goes through here, so the chosen board is saved
/// to settings in one place and the game session never touches preferences.
@MainActor @Observable
final class GameFlow {
    /// A restart waiting for the player to confirm giving up their streak.
    private(set) var pendingNewGame: PendingNewGame?
    /// The finished game's result card, shown a beat after the game ends.
    private(set) var presentedResult: GameResult?
    /// No Guessing couldn't build the board in time.
    var noGuessUnavailable = false

    private let session: GameSession
    private let settings: AppSettings
    private let stats: StatsStore
    private let winDelay: Duration
    private let lossDelay: Duration
    @ObservationIgnored private var resultTask: Task<Void, Never>?

    /// The delays let the final board show for a moment before the card covers it.
    init(
        session: GameSession,
        settings: AppSettings,
        stats: StatsStore,
        winDelay: Duration = .milliseconds(400),
        lossDelay: Duration = .milliseconds(400)
    ) {
        self.session = session
        self.settings = settings
        self.stats = stats
        self.winDelay = winDelay
        self.lossDelay = lossDelay
        session.onFinish = { [weak self] result in self?.gameFinished(result) }
        session.onNoGuessUnavailable = { [weak self] in self?.noGuessUnavailable = true }
    }

    /// Starts a new game on `difficulty` (or the current choice), first asking for confirmation
    /// if abandoning the game in progress would end a streak. Returns whether it started.
    @discardableResult
    func requestNewGame(_ difficulty: Difficulty? = nil) -> Bool {
        let modeStreak = stats.stats(for: session.statsMode).currentStreak
        let overallStreak = stats.overall.current
        if session.game.status == .playing, modeStreak > 0 || overallStreak > 0 {
            pendingNewGame = PendingNewGame(difficulty: difficulty, modeStreak: modeStreak, overallStreak: overallStreak)
            return false
        }
        startNewGame(difficulty)
        return true
    }

    func confirmNewGame() {
        guard let pending = pendingNewGame else { return }
        pendingNewGame = nil
        startNewGame(pending.difficulty)
    }

    func cancelNewGame() {
        pendingNewGame = nil
    }

    func dismissResult() {
        presentedResult = nil
    }

    private func startNewGame(_ difficulty: Difficulty?) {
        let difficulty = difficulty ?? settings.difficulty
        settings.difficulty = difficulty
        if difficulty.isCustom { settings.noteCustomBoard(difficulty) }
        resultTask?.cancel()
        presentedResult = nil
        noGuessUnavailable = false
        session.newGame(difficulty)
    }

    private func gameFinished(_ result: GameResult) {
        let delay = result.won ? winDelay : lossDelay
        resultTask?.cancel()
        resultTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.presentedResult = result
        }
    }
}

struct PendingNewGame: Equatable {
    let difficulty: Difficulty?
    let modeStreak: Int
    let overallStreak: Int

    var message: String {
        if modeStreak > 0, overallStreak > 0, modeStreak != overallStreak {
            return "You'll lose your \(modeStreak)-game streak on this board and your \(overallStreak)-game overall streak."
        }
        return "You'll lose your \(max(modeStreak, overallStreak))-game streak."
    }
}
