import Foundation
import Testing
import SweeperKit
@testable import Freesweeper

struct SavedGameTests {
    @Test func roundTripsAnUnfinishedGame() throws {
        let defaults = makeDefaults()
        let game = startedCornerMineGame()
        SavedGame(game: game, elapsedSeconds: 33.3, isNoGuessBoard: true).save(to: defaults)

        let loaded = try #require(SavedGame.load(from: defaults))
        #expect(loaded.game.board == game.board)
        #expect(loaded.elapsedSeconds == 33.3)
        #expect(loaded.isNoGuessBoard)
    }

    @Test func finishedOrUnstartedGamesAreNotResumed() {
        let defaults = makeDefaults()
        var won = startedCornerMineGame()
        won.reveal(winningTap)
        SavedGame(game: won, elapsedSeconds: 1, isNoGuessBoard: false).save(to: defaults)
        #expect(SavedGame.load(from: defaults) == nil)
        #expect(defaults.data(forKey: "savedGame") == nil, "A rejected save is cleared")

        let fresh = Game(difficulty: Difficulty(width: 9, height: 9, mines: 10), seed: 1)
        SavedGame(game: fresh, elapsedSeconds: 0, isNoGuessBoard: false).save(to: defaults)
        #expect(SavedGame.load(from: defaults) == nil)
    }

    @Test func garbageIsDiscarded() {
        let defaults = makeDefaults()
        defaults.set(Data("{".utf8), forKey: "savedGame")
        #expect(SavedGame.load(from: defaults) == nil)
    }

    @Test func tamperedGameIsDiscarded() throws {
        let defaults = makeDefaults()
        SavedGame(game: startedCornerMineGame(), elapsedSeconds: 1, isNoGuessBoard: false).save(to: defaults)
        let data = try #require(defaults.data(forKey: "savedGame"))
        var json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        var game = try #require(json["game"] as? [String: Any])
        game["flagCount"] = 7
        json["game"] = game
        defaults.set(try JSONSerialization.data(withJSONObject: json), forKey: "savedGame")

        #expect(SavedGame.load(from: defaults) == nil)
    }

    @Test func negativeTimeIsDiscarded() {
        let defaults = makeDefaults()
        SavedGame(game: startedCornerMineGame(), elapsedSeconds: -5, isNoGuessBoard: false).save(to: defaults)
        #expect(SavedGame.load(from: defaults) == nil)
    }

    @Test func massivePresetBoardsCanBeResumed() throws {
        // 60×140 is beyond the custom cap but is a real preset, so it must survive a relaunch.
        let defaults = makeDefaults()
        var game = Game(difficulty: Difficulty(shape: .rectangle, size: .massive, level: .easy), seed: 4)
        game.reveal(Coord(x: 30, y: 70))
        try #require(game.status == .playing)
        SavedGame(game: game, elapsedSeconds: 9, isNoGuessBoard: false).save(to: defaults)
        #expect(SavedGame.load(from: defaults)?.game.difficulty.height == 140)
    }
}
