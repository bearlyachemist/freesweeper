import Foundation
import SweeperKit

/// The game in progress, kept so a relaunch picks up where she left off.
struct SavedGame: Codable {
    var game: Game
    var elapsedSeconds: Double
    /// The logic the board was built for, or `nil` for an ordinary random board.
    var noGuessLogic: NoGuessLogic?
    /// Whether the hint button was showing during the game.
    var hints: Bool

    private static let key = "savedGame"

    init(game: Game, elapsedSeconds: Double, noGuessLogic: NoGuessLogic?, hints: Bool = false) {
        self.game = game
        self.elapsedSeconds = elapsedSeconds
        self.noGuessLogic = noGuessLogic
        self.hints = hints
    }

    private enum CodingKeys: String, CodingKey {
        case game, elapsedSeconds, noGuessLogic, hints
        /// Saves from before Easy existed; those no-guess boards were Hard.
        case isNoGuessBoard
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        game = try container.decode(Game.self, forKey: .game)
        elapsedSeconds = try container.decode(Double.self, forKey: .elapsedSeconds)
        let legacy = try container.decodeIfPresent(Bool.self, forKey: .isNoGuessBoard) ?? false
        noGuessLogic = try container.decodeIfPresent(NoGuessLogic.self, forKey: .noGuessLogic) ?? (legacy ? .hard : nil)
        hints = try container.decodeIfPresent(Bool.self, forKey: .hints) ?? false
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(game, forKey: .game)
        try container.encode(elapsedSeconds, forKey: .elapsedSeconds)
        try container.encodeIfPresent(noGuessLogic, forKey: .noGuessLogic)
        try container.encode(hints, forKey: .hints)
    }

    /// The saved game if it's an unfinished, intact game; anything else is discarded.
    static func load(from defaults: UserDefaults) -> SavedGame? {
        guard let data = defaults.data(forKey: key),
              let saved = try? JSONDecoder().decode(SavedGame.self, from: data),
              saved.game.status == .playing,
              saved.game.isConsistent,
              Difficulty.sizeRange.contains(saved.game.difficulty.width),
              Difficulty.sizeRange.contains(saved.game.difficulty.height),
              saved.elapsedSeconds.isFinite, saved.elapsedSeconds >= 0
        else {
            clear(from: defaults)
            return nil
        }
        return saved
    }

    func save(to defaults: UserDefaults) {
        defaults.set(try? JSONEncoder().encode(self), forKey: Self.key)
    }

    static func clear(from defaults: UserDefaults) {
        defaults.removeObject(forKey: key)
    }
}
