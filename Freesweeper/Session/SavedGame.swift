import Foundation
import SweeperKit

/// The game in progress, kept so a relaunch picks up where she left off.
struct SavedGame: Codable {
    var game: Game
    var elapsedSeconds: Double
    var isNoGuessBoard: Bool

    private static let key = "savedGame"

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
