/// Builds boards that can be cleared from the first tap by logic alone: no 50/50s, ever.
///
/// It starts from an ordinary random layout and lets the solver play it. Whenever the solver
/// gets stuck, one mine on the ambiguous edge is moved into the part of the board nobody has
/// seen yet, and play continues. A board is only returned after a full replay from the first
/// tap clears it, so the guarantee doesn't depend on those intermediate shortcuts.
public enum NoGuessGenerator {
    /// Fresh random layouts to try before giving up.
    static let attempts = 8

    /// A no-guess board for a first tap at `start`, or `nil` if none was found in time (only at
    /// extreme densities), the time limit passed, or the calling task was cancelled.
    /// Deterministic for a given difficulty, seed and start when it finishes.
    public static func generate(
        _ difficulty: Difficulty,
        seed: UInt64,
        safe start: Coord,
        timeLimit: Duration? = nil
    ) -> Board? {
        let grid = Grid(width: difficulty.width, height: difficulty.height)
        guard (0..<grid.width).contains(start.x), (0..<grid.height).contains(start.y) else { return nil }
        let startIndex = start.y * grid.width + start.x
        var rng = SeededGenerator(seed: seed)
        let maxMoves = grid.cellCount * 2
        let deadline = timeLimit.map { ContinuousClock.now + $0 }
        let shouldStop = { Task.isCancelled || deadline.map { ContinuousClock.now >= $0 } ?? false }

        for _ in 0..<attempts {
            let layout = BoardGenerator.random(difficulty, seed: rng.next(), safe: start)
            var play = Playthrough(grid: grid, mines: layout.cells.map(\.isMine), start: startIndex)
            // Whatever the random layout kept clear around the first tap stays clear.
            let protected = Set([startIndex] + grid.neighbors[startIndex].filter { !play.mines[$0] })

            for _ in 0..<maxMoves {
                if shouldStop() { return nil }
                if play.run(shouldStop: shouldStop) {
                    var replay = Playthrough(grid: grid, mines: play.mines, start: startIndex)
                    if replay.run(shouldStop: shouldStop) { return board(grid, mines: replay.mines) }
                    play = replay
                }
                // A solver mistake means this layout can't be trusted; start a fresh one.
                guard !play.hitMine, repair(&play, protected: protected, rng: &rng) else { break }
            }
        }
        return nil
    }

    /// Whether a perfect logical player can clear `board` from a first tap at `start`.
    public static func isSolvable(_ board: Board, from start: Coord) -> Bool {
        let grid = Grid(width: board.width, height: board.height)
        guard board.contains(start), !board[start].isMine else { return false }
        var play = Playthrough(grid: grid, mines: board.cells.map(\.isMine), start: board.index(of: start))
        return play.run()
    }

    /// Moves one mine off the stuck frontier. Returns `false` if there's nothing left to try.
    private static func repair(_ play: inout Playthrough, protected: Set<Int>, rng: inout SeededGenerator) -> Bool {
        let knowledge = play.knowledge
        var frontierMines: [Int] = []
        var unseenSafe: [Int] = []
        var walls: [Int] = []
        for cell in 0..<play.grid.cellCount {
            let touchesRevealed = play.grid.neighbors[cell].contains { knowledge.cells[$0] >= 0 }
            switch knowledge.cells[cell] {
            case Knowledge.unknown where touchesRevealed && play.mines[cell]:
                frontierMines.append(cell)
            case Knowledge.unknown where !touchesRevealed && !play.mines[cell]:
                unseenSafe.append(cell)
            case Knowledge.mine where touchesRevealed:
                walls.append(cell)
            default:
                break
            }
        }

        if !frontierMines.isEmpty, !unseenSafe.isEmpty {
            play.moveMine(
                from: frontierMines[rng.int(below: frontierMines.count)],
                to: unseenSafe[rng.int(below: unseenSafe.count)]
            )
            return true
        }

        // No unseen room left (endgame) or the frontier is sealed by known mines: move a mine
        // anywhere else and replay from the first tap.
        let sources = frontierMines.isEmpty ? walls : frontierMines
        guard !sources.isEmpty else { return false }
        let from = sources[rng.int(below: sources.count)]
        let destinations = (0..<play.grid.cellCount).filter { !play.mines[$0] && !protected.contains($0) }
        guard !destinations.isEmpty else { return false }
        var mines = play.mines
        mines[from] = false
        mines[destinations[rng.int(below: destinations.count)]] = true
        play = Playthrough(grid: play.grid, mines: mines, start: play.start)
        return true
    }

    private static func board(_ grid: Grid, mines: [Bool]) -> Board {
        Board(
            width: grid.width,
            height: grid.height,
            mines: Set(mines.indices.filter { mines[$0] }.map { Coord(x: $0 % grid.width, y: $0 / grid.width) })
        )
    }
}
