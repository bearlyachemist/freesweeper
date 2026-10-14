public enum BoardGenerator {
    /// Places `difficulty.mines` mines uniformly at random, keeping `start` and (when there's
    /// room) its neighbours clear so the first tap always opens an area. A mine count that
    /// doesn't fit is reduced to leave one safe cell, so this never fails.
    public static func random(_ difficulty: Difficulty, seed: UInt64, safe start: Coord) -> Board {
        let empty = Board(width: difficulty.width, height: difficulty.height)
        let mineCount = min(max(difficulty.mines, 0), empty.cells.count - 1)

        var excluded = Set(empty.neighbors(of: start))
        excluded.insert(start)
        if empty.cells.count - excluded.count < mineCount {
            excluded = [start]
        }

        var candidates = empty.coordinates.filter { !excluded.contains($0) }
        var rng = SeededGenerator(seed: seed)
        // Partial Fisher–Yates: only the first `mines` slots need shuffling.
        for i in 0..<mineCount {
            candidates.swapAt(i, i + rng.int(below: candidates.count - i))
        }
        return Board(
            width: difficulty.width,
            height: difficulty.height,
            mines: Set(candidates.prefix(mineCount))
        )
    }
}
