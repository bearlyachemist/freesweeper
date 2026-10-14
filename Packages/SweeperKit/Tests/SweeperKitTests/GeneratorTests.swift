import Testing
@testable import SweeperKit

struct GeneratorTests {
    @Test func sameSeedSameBoard() {
        let start = Coord(x: 4, y: 4)
        let a = BoardGenerator.random(.expert, seed: 42, safe: start)
        let b = BoardGenerator.random(.expert, seed: 42, safe: start)
        let c = BoardGenerator.random(.expert, seed: 43, safe: start)
        #expect(a == b)
        #expect(a != c)
    }

    @Test(arguments: [Coord(x: 4, y: 4), Coord(x: 0, y: 0), Coord(x: 8, y: 3)])
    func placesExactCountAndKeepsStartAreaClear(start: Coord) {
        for seed in UInt64(0)..<200 {
            let board = BoardGenerator.random(.beginner, seed: seed, safe: start)
            #expect(board.mineCount == Difficulty.beginner.mines)
            #expect(!board[start].isMine)
            #expect(board[start].adjacentMines == 0)
        }
    }

    @Test func fallsBackToSingleSafeCellWhenCrowded() {
        let crowded = Difficulty(width: 9, height: 9, mines: 80)
        let board = BoardGenerator.random(crowded, seed: 7, safe: Coord(x: 4, y: 4))
        #expect(board.mineCount == 80)
        #expect(!board[Coord(x: 4, y: 4)].isMine)
    }
}
