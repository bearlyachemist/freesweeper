/// A nudge for a stuck player: where to look, not what to do.
public enum Hint: Equatable, Sendable {
    /// These revealed numbers settle a cell for certain. `usesMineCount` when the mine counter
    /// is part of the reasoning too.
    case clue(numbers: Set<Coord>, usesMineCount: Bool)
    /// Nothing visible settles any cell, so the next move is a guess. `mine` is a mine that can
    /// be shown to get past it.
    case guess(mine: Coord)
}

extension Game {
    /// A hint for the board as the player sees it, or `nil` if the game isn't in progress.
    ///
    /// Only revealed numbers and correct flags count as known; a wrong flag is ignored, so a
    /// hint never builds on a mistake. The simplest reasoning that settles something wins
    /// (single numbers, then pairs, then the mine count, then trying arrangements), preferring
    /// a mine over a safe cell, then whatever is closest to `focus`.
    public func hint(near focus: Coord? = nil) -> Hint? {
        guard status == .playing else { return nil }
        let grid = Grid(width: board.width, height: board.height)
        var knowledge = Knowledge(cellCount: grid.cellCount, totalMines: mineCount)
        for (i, cell) in board.cells.enumerated() {
            switch cell.state {
            case .revealed: knowledge.cells[i] = Int8(cell.adjacentMines)
            case .flagged where cell.isMine: knowledge.cells[i] = Knowledge.mine
            case .flagged, .hidden: break
            }
        }

        let focusIndex = focus.map(board.index(of:))
        func distance(_ cell: Int) -> Int {
            guard let focusIndex else { return 0 }
            return max(abs(cell % grid.width - focusIndex % grid.width), abs(cell / grid.width - focusIndex / grid.width))
        }
        let best = Solver.explain(knowledge, grid: grid).min { a, b in
            (a.isMine ? 0 : 1, distance(a.cell)) < (b.isMine ? 0 : 1, distance(b.cell))
        }
        if let best {
            return .clue(numbers: Set(best.sources.map(board.coord(at:))), usesMineCount: best.usesMineCount)
        }

        // A guess: offer the closest unflagged mine on the edge of what's revealed, if any.
        let mines = board.cells.indices.filter { board.cells[$0].isMine && board.cells[$0].state == .hidden }
        let edge = mines.filter { grid.neighbors[$0].contains { board.cells[$0].state == .revealed } }
        guard let mine = (edge.isEmpty ? mines : edge).min(by: { distance($0) < distance($1) }) else { return nil }
        return .guess(mine: board.coord(at: mine))
    }
}

extension Solver {
    /// A certain cell and the numbers that settle it.
    struct Explanation {
        var cell: Int
        var isMine: Bool
        /// Revealed cells whose numbers settle it.
        var sources: Set<Int>
        var usesMineCount: Bool
    }

    /// Every cell settled at the simplest level that settles anything, each with its reasons.
    static func explain(_ knowledge: Knowledge, grid: Grid) -> [Explanation] {
        let constraints = constraints(knowledge, grid: grid, active: 0..<grid.cellCount)

        // 1. Single numbers.
        var found: [Explanation] = []
        for constraint in constraints {
            let isMine = constraint.mines == constraint.cells.count
            guard constraint.mines == 0 || isMine else { continue }
            for cell in constraint.cells {
                found.append(Explanation(cell: cell, isMine: isMine, sources: [constraint.source], usesMineCount: false))
            }
        }
        if !found.isEmpty { return found }

        // 2. Pairs: the same rule as `pairs`, keeping which two numbers fired.
        for a in constraints {
            for b in constraints where a.source != b.source {
                let onlyA = a.cells.filter { !b.cells.contains($0) }
                let onlyB = b.cells.filter { !a.cells.contains($0) }
                guard onlyA.count < a.cells.count, !(onlyA.isEmpty && onlyB.isEmpty),
                      b.mines - a.mines == onlyB.count else { continue }
                let sources: Set<Int> = [a.source, b.source]
                found += onlyB.map { Explanation(cell: $0, isMine: true, sources: sources, usesMineCount: false) }
                found += onlyA.map { Explanation(cell: $0, isMine: false, sources: sources, usesMineCount: false) }
            }
        }
        if !found.isEmpty { return found }

        // 3. The mine count.
        let counted = countingExplained(knowledge, constraints: constraints)
        if !counted.isEmpty { return counted }

        // 4. Trying arrangements, credited to every number in the cell's region. The count is
        // only part of it when the region's numbers alone don't settle the cell.
        let full = regions(knowledge, grid: grid, constraints: constraints)
        guard !full.isEmpty else { return [] }
        let local = regions(knowledge, grid: grid, constraints: constraints, useMineCount: false)
        let regionOf = regionSources(constraints)
        return explanations(full) { regionOf[$0] ?? [] } usesMineCount: { cell in
            !local.mines.contains(cell) && !local.safe.contains(cell)
        }
    }

    private static func explanations(
        _ deductions: Deductions,
        sources: (Int) -> Set<Int>,
        usesMineCount: (Int) -> Bool
    ) -> [Explanation] {
        deductions.mines.map { Explanation(cell: $0, isMine: true, sources: sources($0), usesMineCount: usesMineCount($0)) }
            + deductions.safe.map { Explanation(cell: $0, isMine: false, sources: sources($0), usesMineCount: usesMineCount($0)) }
    }

    /// For each frontier cell, the numbers of every constraint in its connected region.
    private static func regionSources(_ constraints: [Constraint]) -> [Int: Set<Int>] {
        var parent = Array(constraints.indices)
        func root(_ x: Int) -> Int {
            var x = x
            while parent[x] != x { parent[x] = parent[parent[x]]; x = parent[x] }
            return x
        }
        var firstConstraint: [Int: Int] = [:]
        for (i, constraint) in constraints.enumerated() {
            for cell in constraint.cells {
                if let j = firstConstraint[cell] { parent[root(i)] = root(j) } else { firstConstraint[cell] = i }
            }
        }
        var sourcesByRoot: [Int: Set<Int>] = [:]
        for (i, constraint) in constraints.enumerated() { sourcesByRoot[root(i), default: []].insert(constraint.source) }
        return firstConstraint.mapValues { sourcesByRoot[root($0)]! }
    }
}
