import Testing
@testable import SweeperKit

struct HintTests {
    /// A game on a fixed layout with `revealed` dug, in order.
    private func game(_ width: Int, _ height: Int, mines: [Coord], revealed: [Coord], flags: [Coord] = []) -> Game {
        var game = Game(board: Board(width: width, height: height, mines: Set(mines)))
        for flag in flags { game.toggleFlag(flag) }
        for coord in revealed { game.reveal(coord) }
        return game
    }

    @Test func singleNumberPointsAtTheMineNearestTheFocus() {
        // * 1 1 * ? ?
        let g = game(6, 1, mines: [Coord(x: 0, y: 0), Coord(x: 3, y: 0)], revealed: [Coord(x: 1, y: 0), Coord(x: 2, y: 0)])
        #expect(g.hint(near: Coord(x: 1, y: 0)) == .clue(numbers: [Coord(x: 1, y: 0)], usesMineCount: false))
        #expect(g.hint(near: Coord(x: 2, y: 0)) == .clue(numbers: [Coord(x: 2, y: 0)], usesMineCount: false))
    }

    @Test func mineCountIsFlaggedWhenItsNeeded() {
        // * 1 ? ?   with one mine: the 1 holds it, so the far cell is safe.
        let g = game(4, 1, mines: [Coord(x: 0, y: 0)], revealed: [Coord(x: 1, y: 0)])
        #expect(g.hint() == .clue(numbers: [Coord(x: 1, y: 0)], usesMineCount: true))
    }

    @Test func wrongFlagIsIgnored() {
        // A wrong flag stops the opening at (0,1); the zeros beside it still prove it safe.
        let g = game(3, 3, mines: [Coord(x: 0, y: 0)], revealed: [Coord(x: 2, y: 2)], flags: [Coord(x: 0, y: 1)])
        guard case .clue(let numbers, let usesMineCount) = g.hint() else {
            Issue.record("Expected a clue")
            return
        }
        #expect(numbers.count == 1 && numbers.isSubset(of: [Coord(x: 0, y: 2), Coord(x: 1, y: 2)]))
        #expect(!usesMineCount)
    }

    @Test func fiftyFiftyOffersTheMine() {
        // * ?
        // ? 1   one mine among three cells: a guess.
        let g = game(2, 2, mines: [Coord(x: 0, y: 0)], revealed: [Coord(x: 1, y: 1)])
        #expect(g.hint() == .guess(mine: Coord(x: 0, y: 0)))
    }

    @Test func noHintOutsideAGame() {
        #expect(Game(difficulty: .beginner, seed: 1).hint() == nil)
        let lost = game(2, 1, mines: [Coord(x: 0, y: 0)], revealed: [Coord(x: 0, y: 0)])
        #expect(lost.hint() == nil)
    }

    @Test func noGuessBoardsAlwaysHaveAClue() throws {
        // Follow hints on a no-guess board to the end: every step must be a clue, never a guess.
        let difficulty = Difficulty(width: 16, height: 16, mines: 50)
        for logic in NoGuessLogic.allCases {
            let start = Coord(x: 8, y: 8)
            let board = try #require(NoGuessGenerator.generate(difficulty, seed: 3, safe: start, logic: logic))
            var g = Game(board: board)
            g.reveal(start)
            var steps = 0
            while g.status == .playing, steps < 1_000 {
                steps += 1
                guard case .clue = g.hint() else {
                    Issue.record("\(logic): no clue after \(steps) steps")
                    return
                }
                // Act on the solver's own next move, flagging mines so play carries on.
                let grid = Grid(width: board.width, height: board.height)
                var k = Knowledge(cellCount: grid.cellCount, totalMines: g.mineCount)
                for (i, cell) in g.board.cells.enumerated() {
                    if cell.state == .revealed { k.cells[i] = Int8(cell.adjacentMines) }
                    if cell.state == .flagged { k.cells[i] = Knowledge.mine }
                }
                let next = try #require(Solver.explain(k, grid: grid).first)
                let coord = board.coord(at: next.cell)
                if next.isMine { g.toggleFlag(coord) } else { g.reveal(coord) }
            }
            #expect(g.status == .won, "\(logic)")
        }
    }
}
