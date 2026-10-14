import SwiftUI
import SweeperKit

enum InputMode {
    /// Tap digs, long press flags.
    case reveal
    /// Tap flags, long press digs.
    case flag
}

/// The game being played: wraps the engine with the timer, input mode, touch feedback, stats
/// recording and saving. What's shown around the game (confirmations, alerts, the result card)
/// lives in `GameFlow`, which hears about finished games through `onFinish`.
@MainActor @Observable
final class GameSession {
    private(set) var game: Game
    private(set) var clock: GameClock
    var inputMode: InputMode = .reveal
    /// The player locked the board. Only takes effect while the lock button is shown, so hiding
    /// the button can never leave the board stuck.
    var isLocked = false
    /// Cells drawn pushed-in while a finger is down.
    private(set) var pressedCells: Set<Coord> = []
    /// Bumped on every flag change; drives haptics.
    private(set) var flagChanges = 0
    /// A no-guess board is being built after the first tap; the board ignores input meanwhile.
    private(set) var isGenerating = false
    /// Whether the current board's mines came from the no-guess generator.
    private(set) var isNoGuessBoard: Bool
    /// Called with the recorded result when a game is won or lost.
    @ObservationIgnored var onFinish: (@MainActor (GameResult) -> Void)?
    /// Called when No Guessing couldn't build the board in time; nothing was dug.
    @ObservationIgnored var onNoGuessUnavailable: (@MainActor () -> Void)?

    private let settings: AppSettings
    private let sounds: any SoundPlaying
    private let stats: StatsStore
    private let defaults: UserDefaults
    /// How long No Guessing may spend building a board before giving up.
    private let noGuessTimeLimit: Duration
    private var tickTask: Task<Void, Never>?
    /// The background no-guess search, kept so a new game or backgrounding can stop it.
    private var generation: Task<Board?, Never>?
    /// Identifies the current game so late async work can't land on a newer one.
    private var gameID = 0

    init(
        settings: AppSettings,
        sounds: any SoundPlaying,
        stats: StatsStore,
        defaults: UserDefaults = .standard,
        noGuessTimeLimit: Duration = .seconds(5)
    ) {
        self.settings = settings
        self.sounds = sounds
        self.stats = stats
        self.defaults = defaults
        self.noGuessTimeLimit = noGuessTimeLimit
        if let saved = SavedGame.load(from: defaults) {
            game = saved.game
            clock = GameClock(elapsed: .seconds(saved.elapsedSeconds))
            isNoGuessBoard = saved.isNoGuessBoard
        } else {
            game = Game(difficulty: settings.difficulty, seed: .random(in: .min ... .max))
            clock = GameClock()
            isNoGuessBoard = false
        }
    }

    // MARK: - Derived state

    var face: SmileyFace {
        switch game.status {
        case .won: .won
        case .lost: .lost
        case .ready, .playing: pressedCells.isEmpty && !isGenerating ? .normal : .pressing
        }
    }

    /// Whole seconds played, from 0, capped at the display's five digits. Matches the recorded
    /// time rounded down.
    var displaySeconds: Int {
        min(99_999, Int(clock.elapsed().seconds))
    }

    /// Whether board taps are being ignored right now.
    var isInputLocked: Bool { isLocked && settings.showLockButton }

    /// The mode of the board being played. Before the first dig the No Guessing switch decides;
    /// after, what the board actually is.
    var statsMode: StatsMode {
        StatsMode(difficulty: game.difficulty, noGuessing: game.needsMines ? settings.noGuessing : isNoGuessBoard)
    }

    // MARK: - Actions

    /// Starts a fresh game on `difficulty`. Abandoning a started game records it as a loss.
    func newGame(_ difficulty: Difficulty) {
        // Walking away from a started game counts as a loss, so restarting can't save a streak.
        if game.status == .playing {
            clock.pause()
            stats.record(won: false, time: clock.elapsed().seconds, mode: statsMode)
        }
        cancelGeneration()
        game = Game(difficulty: difficulty, seed: .random(in: .min ... .max))
        clock.reset()
        pressedCells = []
        gameID += 1
        isNoGuessBoard = false
        SavedGame.clear(from: defaults)
        updateTicking()
    }

    func tap(_ coord: Coord) {
        guard !isGenerating, !isInputLocked else { return }
        // Tapping a revealed number chords, whatever the mode.
        if game.board[coord].state == .revealed {
            update { $0.chord(coord) }
        } else {
            inputMode == .reveal ? dig(coord) : flag(coord)
        }
    }

    func longPress(_ coord: Coord) {
        guard !isGenerating, !isInputLocked, game.board[coord].state != .revealed else { return }
        inputMode == .reveal ? flag(coord) : dig(coord)
    }

    /// Finger down/moved (`coord`) or lifted (`nil`).
    func press(_ coord: Coord?) {
        let cells = isInputLocked ? [] : previewCells(for: coord)
        if cells != pressedCells { pressedCells = cells }
    }

    /// Runs the clock only while the app is in front, and saves the game on the way out.
    func scenePhaseChanged(_ phase: ScenePhase) {
        if phase == .active {
            if game.status == .playing { clock.start() }
        } else {
            clock.pause()
            // A half-built no-guess board is dropped; the first tap simply needs repeating.
            cancelGeneration()
            persist()
        }
        updateTicking()
    }

    // MARK: - Internals

    private func persist() {
        if game.status == .playing {
            SavedGame(game: game, elapsedSeconds: clock.elapsed().seconds, isNoGuessBoard: isNoGuessBoard)
                .save(to: defaults)
        } else {
            SavedGame.clear(from: defaults)
        }
    }

    private func dig(_ coord: Coord) {
        if game.needsMines, settings.noGuessing, game.board[coord].state == .hidden {
            startNoGuessGame(at: coord)
        } else {
            update { $0.reveal(coord) }
        }
    }

    /// Builds a no-guess board around the first tap off the main thread, then digs there.
    /// If none is found within the time limit, nothing is dug and the player is told.
    private func startNoGuessGame(at coord: Coord) {
        isGenerating = true
        pressedCells = []
        let id = gameID
        let difficulty = game.difficulty
        let seed = game.seed
        let timeLimit = noGuessTimeLimit
        let worker = Task.detached(priority: .userInitiated) {
            NoGuessGenerator.generate(difficulty, seed: seed, safe: coord, timeLimit: timeLimit)
        }
        generation = worker
        Task {
            let layout = await worker.value
            guard id == gameID, !worker.isCancelled else { return }
            generation = nil
            isGenerating = false
            guard let layout else {
                onNoGuessUnavailable?()
                return
            }
            isNoGuessBoard = true
            game.placeMines(layout)
            update { $0.reveal(coord) }
        }
    }

    private func cancelGeneration() {
        generation?.cancel()
        generation = nil
        isGenerating = false
    }

    private func flag(_ coord: Coord) {
        guard game.toggleFlag(coord) else { return }
        flagChanges += 1
        play(.flag)
    }

    private func update(_ action: (inout Game) -> Bool) {
        guard action(&game) else { return }
        switch game.status {
        case .playing:
            clock.start()
            play(.reveal)
        case .won:
            clock.pause()
            play(.win)
            finish(won: true)
        case .lost:
            clock.pause()
            play(.explosion)
            finish(won: false)
        case .ready:
            break
        }
        updateTicking()
    }

    private func finish(won: Bool) {
        SavedGame.clear(from: defaults)
        onFinish?(stats.record(won: won, time: clock.elapsed().seconds, mode: statsMode))
    }

    private func play(_ effect: SoundEffect) {
        if settings.allowsSound(effect) { sounds.play(effect) }
    }

    /// Runs a once-a-second tick aligned to the timer display while the clock runs.
    private func updateTicking() {
        guard clock.isRunning else {
            tickTask?.cancel()
            tickTask = nil
            return
        }
        guard tickTask == nil else { return }
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let elapsed = self?.clock.elapsed().seconds else { return }
                try? await Task.sleep(for: .seconds(1 - elapsed.truncatingRemainder(dividingBy: 1)))
                guard !Task.isCancelled, let self, self.clock.isRunning else { return }
                self.play(.tick)
            }
        }
    }

    /// What a finger at `coord` would act on: the cell itself if it would be dug, or the hidden
    /// neighbours of a number (the classic chord preview).
    private func previewCells(for coord: Coord?) -> Set<Coord> {
        guard let coord, !game.status.isOver, game.board.contains(coord) else { return [] }
        let board = game.board
        switch board[coord].state {
        case .hidden:
            return inputMode == .reveal ? [coord] : []
        case .revealed where board[coord].adjacentMines > 0:
            return Set(board.neighbors(of: coord).filter { board[$0].state == .hidden })
        case .revealed, .flagged:
            return []
        }
    }
}
