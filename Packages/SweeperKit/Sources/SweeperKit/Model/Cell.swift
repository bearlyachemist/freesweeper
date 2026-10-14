public enum CellState: Hashable, Sendable, Codable {
    case hidden
    case flagged
    case revealed
}

public struct Cell: Hashable, Sendable, Codable {
    public internal(set) var isMine: Bool
    /// Mines in the eight surrounding cells. Computed once when the board is built.
    public internal(set) var adjacentMines: Int
    public internal(set) var state: CellState

    init(isMine: Bool = false, adjacentMines: Int = 0, state: CellState = .hidden) {
        self.isMine = isMine
        self.adjacentMines = adjacentMines
        self.state = state
    }
}
