import Foundation
import SweeperKit
@testable import Freesweeper

/// Records effects instead of playing them.
@MainActor
final class SoundRecorder: SoundPlaying {
    private(set) var played: [SoundEffect] = []
    func play(_ effect: SoundEffect) { played.append(effect) }
}

/// A fresh, empty defaults domain so tests never share or leak state.
func makeDefaults() -> UserDefaults {
    let name = "FreesweeperTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

/// 8×8 with one mine in the top-left corner, already started: (1, 1) is revealed as a "1",
/// so tapping `winningTap` floods the rest and wins, and `mineTap` loses.
func startedCornerMineGame() -> Game {
    var game = Game(board: Board(width: 8, height: 8, mines: [Coord(x: 0, y: 0)]))
    game.reveal(Coord(x: 1, y: 1))
    return game
}

let winningTap = Coord(x: 7, y: 7)
let mineTap = Coord(x: 0, y: 0)
let cornerNumber = Coord(x: 1, y: 1)

/// The app's object graph wired to throwaway storage and a sound recorder.
@MainActor
struct Harness {
    let defaults: UserDefaults
    let settings: AppSettings
    let stats: StatsStore
    let sounds: SoundRecorder
    let session: GameSession
    let flow: GameFlow

    init(
        saved: SavedGame? = nil,
        noGuessTimeLimit: Duration = .seconds(5),
        configure: (AppSettings) -> Void = { _ in }
    ) {
        defaults = makeDefaults()
        saved?.save(to: defaults)
        settings = AppSettings(defaults: defaults)
        configure(settings)
        stats = StatsStore(defaults: defaults)
        sounds = SoundRecorder()
        session = GameSession(
            settings: settings,
            sounds: sounds,
            stats: stats,
            defaults: defaults,
            noGuessTimeLimit: noGuessTimeLimit
        )
        flow = GameFlow(session: session, settings: settings, stats: stats, winDelay: .zero, lossDelay: .zero)
    }

    /// A harness already partway through the corner-mine game.
    static func started(configure: (AppSettings) -> Void = { _ in }) -> Harness {
        Harness(saved: SavedGame(game: startedCornerMineGame(), elapsedSeconds: 12.5, noGuessLogic: nil), configure: configure)
    }
}

/// Polls `condition` on the main actor until it holds or `timeout` passes.
@MainActor
func eventually(timeout: Duration = .seconds(10), _ condition: () -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while !condition() {
        if ContinuousClock.now > deadline { return false }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return true
}
