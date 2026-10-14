import Foundation
import Testing
@testable import SweeperKit

struct GameTests {
    /// 4×4 with a single mine in the top-left corner.
    private func cornerMineGame() -> Game {
        Game(board: Board(width: 4, height: 4, mines: [Coord(x: 0, y: 0)]))
    }

    @Test func floodFillOpensBoardAndWins() {
        var game = cornerMineGame()
        let changed = game.reveal(Coord(x: 3, y: 3))
        #expect(changed)
        #expect(game.status == .won)
        #expect(game.board[Coord(x: 0, y: 0)].state == .flagged)
        #expect(game.minesRemaining == 0)
    }

    @Test func revealingNumberOpensOnlyThatCell() {
        var game = cornerMineGame()
        game.reveal(Coord(x: 1, y: 1))
        #expect(game.status == .playing)
        #expect(game.board.cells.count { $0.state == .revealed } == 1)
    }

    @Test func revealingMineLoses() {
        var game = cornerMineGame()
        game.reveal(Coord(x: 0, y: 0))
        #expect(game.status == .lost(exploded: Coord(x: 0, y: 0)))
        let changedAfterLoss = game.reveal(Coord(x: 3, y: 3))
        #expect(!changedAfterLoss, "No moves after the game ends")
    }

    @Test func flagToggles() {
        var game = cornerMineGame()
        let c = Coord(x: 0, y: 0)
        game.toggleFlag(c)
        #expect(game.board[c].state == .flagged)
        #expect(game.minesRemaining == 0)
        let dugFlag = game.reveal(c)
        #expect(!dugFlag, "Flagged cells can't be dug")
        game.toggleFlag(c)
        #expect(game.board[c].state == .hidden)
        #expect(game.minesRemaining == 1)
    }

    @Test func overFlaggingGoesNegative() {
        var game = cornerMineGame()
        game.toggleFlag(Coord(x: 1, y: 1))
        game.toggleFlag(Coord(x: 2, y: 2))
        #expect(game.minesRemaining == -1)
    }

    @Test func chordWithCorrectFlagClearsNeighbors() {
        var game = cornerMineGame()
        let number = Coord(x: 1, y: 1)
        game.reveal(number)
        #expect(!game.canChord(number), "No flags yet")
        game.toggleFlag(Coord(x: 0, y: 0))
        let chorded = game.chord(number)
        #expect(chorded)
        #expect(game.status == .won)
    }

    @Test func chordWithWrongFlagLoses() {
        var game = cornerMineGame()
        let number = Coord(x: 1, y: 1)
        game.reveal(number)
        game.toggleFlag(Coord(x: 2, y: 2))
        let chorded = game.chord(number)
        #expect(chorded)
        #expect(game.status == .lost(exploded: Coord(x: 0, y: 0)))
    }

    @Test func firstRevealIsSafeAndOpensArea() {
        for seed in UInt64(0)..<100 {
            var game = Game(difficulty: .expert, seed: seed)
            let start = Coord(x: 8, y: 15)
            game.reveal(start)
            #expect(game.status == .playing)
            #expect(game.board.mineCount == Difficulty.expert.mines)
            #expect(game.board.cells.count { $0.state == .revealed } >= 9)
        }
    }

    @Test func flagsBeforeFirstRevealSurvive() {
        var game = Game(difficulty: .beginner, seed: 1)
        let flagged = Coord(x: 0, y: 0)
        game.toggleFlag(flagged)
        #expect(game.status == .ready)
        game.reveal(Coord(x: 8, y: 8))
        #expect(game.board[flagged].state == .flagged)
        #expect(game.flagCount == 1)
    }

    @Test func sameSeedAndStartReplaysIdentically() {
        var a = Game(difficulty: .intermediate, seed: 99)
        var b = Game(difficulty: .intermediate, seed: 99)
        a.reveal(Coord(x: 5, y: 5))
        b.reveal(Coord(x: 5, y: 5))
        #expect(a.board == b.board)
    }

    @Test func freshAndPlayedGamesAreConsistent() {
        var game = Game(difficulty: .beginner, seed: 3)
        #expect(game.isConsistent)
        game.toggleFlag(Coord(x: 0, y: 0))
        game.reveal(Coord(x: 5, y: 5))
        #expect(game.isConsistent)
    }

    @Test func gameSurvivesEncodingRoundTrip() throws {
        var game = Game(difficulty: .intermediate, seed: 11)
        game.reveal(Coord(x: 8, y: 8))
        game.toggleFlag(Coord(x: 0, y: 0))
        let decoded = try JSONDecoder().decode(Game.self, from: JSONEncoder().encode(game))
        #expect(decoded.isConsistent)
        #expect(decoded.board == game.board)
        #expect(decoded.status == game.status)
        #expect(decoded.minesRemaining == game.minesRemaining)
    }

    @Test func oversizedMineCountStillPlays() {
        // More mines than cells: the generator leaves one safe cell, and the game counts real mines.
        var game = Game(difficulty: Difficulty(width: 3, height: 3, mines: 50), seed: 1)
        game.reveal(Coord(x: 1, y: 1))
        #expect(game.mineCount == 8)
        #expect(game.status == .won)
    }
}
