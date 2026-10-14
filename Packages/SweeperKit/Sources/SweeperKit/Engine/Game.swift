/// The rules of a single game: reveal, flag, chord, and win/loss.
///
/// Mines are placed lazily on the first reveal so that tap is always safe. Flags placed
/// before then carry over onto the generated board.
public struct Game: Sendable, Codable {
    public let difficulty: Difficulty
    public let seed: UInt64
    public private(set) var board: Board
    public private(set) var status: GameStatus = .ready
    public private(set) var flagCount = 0
    /// Mines on the board: the difficulty's count until they're placed, then the real count.
    public private(set) var mineCount: Int

    private var minesPlaced: Bool
    private var revealedCount = 0

    /// A random game whose mines are placed on the first reveal.
    public init(difficulty: Difficulty, seed: UInt64) {
        self.difficulty = difficulty
        self.seed = seed
        self.board = Board(width: difficulty.width, height: difficulty.height)
        self.mineCount = difficulty.mines
        self.minesPlaced = false
    }

    /// A game on a fixed layout (tests, and later puzzles).
    public init(board: Board) {
        self.difficulty = Difficulty(width: board.width, height: board.height, mines: board.mineCount)
        self.seed = 0
        self.board = board
        self.mineCount = board.mineCount
        self.minesPlaced = true
        self.revealedCount = board.cells.count { $0.state == .revealed }
        self.flagCount = board.cells.count { $0.state == .flagged }
    }

    /// True until the first dig places the mines.
    public var needsMines: Bool { !minesPlaced }

    /// The classic counter: mines minus flags. Goes negative if over-flagged.
    public var minesRemaining: Int { mineCount - flagCount }

    /// Whether every internal count agrees with the board. Check this on a game decoded from
    /// storage before playing it; a game built and played through this API is always consistent.
    public var isConsistent: Bool {
        board.isWellFormed
            && board.width == difficulty.width
            && board.height == difficulty.height
            && flagCount == board.cells.count { $0.state == .flagged }
            && revealedCount == board.cells.count { $0.state == .revealed }
            && (!minesPlaced || mineCount == board.mineCount)
    }

    // MARK: - Actions

    /// Digs a hidden cell. Returns whether anything changed.
    @discardableResult
    public mutating func reveal(_ coord: Coord) -> Bool {
        guard !status.isOver, board.contains(coord), board[coord].state == .hidden else { return false }
        if !minesPlaced { placeMines(avoiding: coord) }
        status = .playing

        if board[coord].isMine {
            status = .lost(exploded: coord)
        } else {
            floodReveal(from: coord)
            checkForWin()
        }
        return true
    }

    /// Flags or unflags a hidden cell. Returns whether anything changed.
    @discardableResult
    public mutating func toggleFlag(_ coord: Coord) -> Bool {
        guard !status.isOver, board.contains(coord) else { return false }
        switch board[coord].state {
        case .revealed:
            return false
        case .hidden:
            board[coord].state = .flagged
            flagCount += 1
        case .flagged:
            board[coord].state = .hidden
            flagCount -= 1
        }
        return true
    }

    /// Whether `coord` is a revealed number with exactly that many flags around it and
    /// something left to dig.
    public func canChord(_ coord: Coord) -> Bool {
        guard !status.isOver, board.contains(coord) else { return false }
        let cell = board[coord]
        guard cell.state == .revealed, cell.adjacentMines > 0 else { return false }
        let neighbors = board.neighbors(of: coord)
        return neighbors.count { board[$0].state == .flagged } == cell.adjacentMines
            && neighbors.contains { board[$0].state == .hidden }
    }

    /// Digs every unflagged neighbour of a satisfied number. A wrong flag loses the game.
    @discardableResult
    public mutating func chord(_ coord: Coord) -> Bool {
        guard canChord(coord) else { return false }
        for neighbor in board.neighbors(of: coord) where board[neighbor].state == .hidden {
            if board[neighbor].isMine {
                status = .lost(exploded: neighbor)
                return true
            }
            floodReveal(from: neighbor)
        }
        checkForWin()
        return true
    }

    /// Uses `layout` for a game whose mines aren't placed yet, e.g. a no-guess board built off
    /// the main thread. Flags already placed are kept.
    public mutating func placeMines(_ layout: Board) {
        guard !minesPlaced, layout.width == board.width, layout.height == board.height else { return }
        var layout = layout
        for i in board.cells.indices {
            layout.cells[i].state = board.cells[i].state
        }
        board = layout
        mineCount = layout.mineCount
        minesPlaced = true
    }

    // MARK: - Internals

    private mutating func placeMines(avoiding start: Coord) {
        placeMines(BoardGenerator.random(difficulty, seed: seed, safe: start))
    }

    /// Reveals `start`, spreading through zero cells. Flags stop the spread.
    private mutating func floodReveal(from start: Coord) {
        var stack = [start]
        while let coord = stack.popLast() {
            guard board[coord].state == .hidden else { continue }
            board[coord].state = .revealed
            revealedCount += 1
            if board[coord].adjacentMines == 0 {
                stack.append(contentsOf: board.neighbors(of: coord))
            }
        }
    }

    private mutating func checkForWin() {
        guard revealedCount == board.cells.count - mineCount else { return }
        status = .won
        // Classic behaviour: flag every remaining mine and zero the counter.
        for i in board.cells.indices where board.cells[i].isMine {
            board.cells[i].state = .flagged
        }
        flagCount = mineCount
    }
}
