/// Plays a layout from the first tap using only the solver's certain deductions, the way a
/// perfect player who never guesses would.
struct Playthrough {
    let grid: Grid
    let start: Int
    private(set) var mines: [Bool]
    private(set) var knowledge: Knowledge
    private var numbers: [Int8]
    private var revealedCount = 0
    private let safeCount: Int
    /// Revealed cells that may still touch an unknown: the only ones the solver needs to look at.
    private var active: Set<Int> = []
    /// Set if the solver ever calls a mine safe. That would be a solver bug; the playthrough
    /// stops and reports failure rather than crashing, so the board is simply rejected.
    private(set) var hitMine = false

    init(grid: Grid, mines: [Bool], start: Int) {
        self.grid = grid
        self.start = start
        self.mines = mines
        let mineCount = mines.count { $0 }
        self.knowledge = Knowledge(cellCount: grid.cellCount, totalMines: mineCount)
        self.safeCount = grid.cellCount - mineCount
        self.numbers = grid.neighbors.map { neighbors in Int8(neighbors.count { mines[$0] }) }
        reveal(start)
    }

    var isSolved: Bool { revealedCount == safeCount }

    /// Applies deductions until the board is cleared (`true`), or nothing more is certain,
    /// the solver was wrong, or `shouldStop` returns true (`false`).
    mutating func run(shouldStop: () -> Bool = { false }) -> Bool {
        while !isSolved {
            if hitMine || shouldStop() { return false }
            active = active.filter { cell in
                grid.neighbors[cell].contains { knowledge.cells[$0] == Knowledge.unknown }
            }
            let deductions = Solver.deduce(knowledge, grid: grid, active: active)
            if deductions.isEmpty { return false }
            for cell in deductions.mines { knowledge.cells[cell] = Knowledge.mine }
            for cell in deductions.safe { reveal(cell) }
        }
        return !hitMine
    }

    /// Moves a mine from an unknown cell to an unknown cell no revealed number touches.
    /// What's already known stays true, so play can continue from here.
    mutating func moveMine(from: Int, to: Int) {
        mines[from] = false
        mines[to] = true
        for neighbor in grid.neighbors[from] { setNumber(of: neighbor, by: -1) }
        for neighbor in grid.neighbors[to] { setNumber(of: neighbor, by: 1) }
    }

    private mutating func setNumber(of cell: Int, by delta: Int8) {
        numbers[cell] += delta
        if knowledge.cells[cell] >= 0 { knowledge.cells[cell] = numbers[cell] }
    }

    /// Reveals a safe cell, opening up zeros like the game does.
    private mutating func reveal(_ cell: Int) {
        var stack = [cell]
        while let cell = stack.popLast() {
            guard knowledge.cells[cell] == Knowledge.unknown else { continue }
            if mines[cell] {
                assertionFailure("Solver deduced a mine as safe")
                hitMine = true
                return
            }
            knowledge.cells[cell] = numbers[cell]
            revealedCount += 1
            active.insert(cell)
            if numbers[cell] == 0 { stack.append(contentsOf: grid.neighbors[cell]) }
        }
    }
}
