import Testing
@testable import SweeperKit

/// Builds what a player sees from rows of: `?` unknown, `*` known mine, `0`–`8` revealed.
private func knowledge(_ rows: [String], mines: Int) -> (Knowledge, Grid) {
    let grid = Grid(width: rows[0].count, height: rows.count)
    var knowledge = Knowledge(cellCount: grid.cellCount, totalMines: mines)
    for (i, character) in rows.joined().enumerated() {
        switch character {
        case "?": knowledge.cells[i] = Knowledge.unknown
        case "*": knowledge.cells[i] = Knowledge.mine
        default: knowledge.cells[i] = Int8(String(character))!
        }
    }
    return (knowledge, grid)
}

struct SolverTests {
    @Test func satisfiedNumberClearsNeighbors() {
        let (k, grid) = knowledge(["*??", "1??"], mines: 2)
        #expect(Solver.deduce(k, grid: grid).safe == [1, 4])
    }

    @Test func fullNumberMarksMines() {
        // ? 1
        // 1 1   → every 1 touches only the corner.
        let (k, grid) = knowledge(["?1", "11"], mines: 1)
        #expect(Solver.deduce(k, grid: grid).mines == [0])
    }

    @Test func oneTwoOne() {
        // ? ? ?
        // 1 2 1   → the outer two are mines, the middle is safe.
        var (k, grid) = knowledge(["???", "121"], mines: 2)
        var found = Deductions()
        for _ in 0..<3 {
            let step = Solver.deduce(k, grid: grid)
            found.safe.formUnion(step.safe)
            found.mines.formUnion(step.mines)
            for cell in step.mines { k.cells[cell] = Knowledge.mine }
            for cell in step.safe { k.cells[cell] = 0 } // value irrelevant for this check
        }
        #expect(found.mines == [0, 2])
        #expect(found.safe == [1])
    }

    @Test func subsetWithEqualCountClearsTheRest() {
        // ? ? ?
        // 1 1 1   with one mine: the left 1 ⊂ middle 1, so the right column is safe.
        let (k, grid) = knowledge(["???", "111"], mines: 1)
        #expect(Solver.deduce(k, grid: grid).safe.contains(2))
    }

    @Test func mediumCountsMinesWhereEasyCannot() {
        // ? 1 ? ?   → the 1 holds the only mine, so the far cell is safe.
        let (k, grid) = knowledge(["?1??"], mines: 1)
        #expect(Solver.deduce(k, grid: grid, logic: .easy).isEmpty)
        #expect(Solver.deduce(k, grid: grid, logic: .medium).safe == [3])
    }

    @Test func mediumFillsTheRestWhenTheCountNeedsIt() {
        // ? 1 ? ?   with two mines: one must be outside the 1, and only the far cell is.
        let (k, grid) = knowledge(["?1??"], mines: 2)
        #expect(Solver.deduce(k, grid: grid, logic: .medium).mines == [3])
    }

    @Test func fiftyFiftyIsNotGuessed() {
        let (k, grid) = knowledge(["??", "11"], mines: 1)
        #expect(Solver.deduce(k, grid: grid).isEmpty)
    }

    @Test func mineCountClearsUnseenCells() {
        // 1 * ? ? ?  — the only mine is known, so the unseen cells are safe.
        let (k, grid) = knowledge(["1*???"], mines: 1)
        #expect(Solver.deduce(k, grid: grid).safe == [2, 3, 4])
    }

    @Test func mineCountClearsInteriorOnceFrontierHoldsTheLastMine() {
        // 1 ? ? ?
        // ? ? ? ?   The 1's three neighbours hold one mine, and that's the only mine left,
        //           so every cell the 1 doesn't touch is safe (needs region search + count).
        let (k, grid) = knowledge(["1???", "????"], mines: 1)
        let result = Solver.deduce(k, grid: grid)
        #expect(result.safe == [2, 3, 6, 7])
        #expect(result.mines.isEmpty)
    }

    @Test(arguments: [Difficulty.beginner, .intermediate, .expert])
    func neverDeducesWrongOnRandomBoards(difficulty: Difficulty) {
        // Playthrough flags `hitMine` (and asserts in debug) if the solver ever calls a mine safe.
        let grid = Grid(width: difficulty.width, height: difficulty.height)
        let start = Coord(x: difficulty.width / 2, y: difficulty.height / 2)
        for seed in UInt64(0)..<60 {
            let board = BoardGenerator.random(difficulty, seed: seed, safe: start)
            var play = Playthrough(grid: grid, mines: board.cells.map(\.isMine), start: board.index(of: start))
            _ = play.run()
            #expect(!play.hitMine)
            for (i, value) in play.knowledge.cells.enumerated() where value == Knowledge.mine {
                #expect(board.cells[i].isMine)
            }
        }
    }
}
