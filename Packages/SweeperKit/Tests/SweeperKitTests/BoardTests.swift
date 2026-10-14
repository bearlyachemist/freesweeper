import Testing
@testable import SweeperKit

struct BoardTests {
    @Test func adjacencyCounts() {
        // M . .
        // . . .
        // . . M
        let board = Board(width: 3, height: 3, mines: [Coord(x: 0, y: 0), Coord(x: 2, y: 2)])
        #expect(board[Coord(x: 1, y: 1)].adjacentMines == 2)
        #expect(board[Coord(x: 1, y: 0)].adjacentMines == 1)
        #expect(board[Coord(x: 2, y: 0)].adjacentMines == 0)
        #expect(board.mineCount == 2)
    }

    @Test func neighborsRespectEdges() {
        let board = Board(width: 4, height: 3)
        #expect(board.neighbors(of: Coord(x: 0, y: 0)).count == 3)
        #expect(board.neighbors(of: Coord(x: 1, y: 0)).count == 5)
        #expect(board.neighbors(of: Coord(x: 1, y: 1)).count == 8)
    }

    @Test func coordinatesAreRowMajor() {
        let board = Board(width: 4, height: 3)
        for (i, coord) in board.coordinates.enumerated() {
            #expect(board.index(of: coord) == i)
        }
    }

    @Test func customDifficultyClamps() {
        let d = Difficulty.custom(width: 500, height: 2, mines: 10_000)
        #expect(d.width == Difficulty.sizeRange.upperBound)
        #expect(d.height == 8)
        #expect(d.mines == d.width * 8 - 9)
    }
}
