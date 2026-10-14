import SweeperKit

/// What a cell should look like right now: the cell's state combined with the game outcome
/// and touch feedback. Renderers only ever see this, never the engine types.
enum CellVisual: Hashable, Sendable {
    case hidden
    /// Covered, but under the finger (or a chord preview).
    case pressed
    case flagged
    case revealed(Int)
    /// Shown after a loss.
    case mine
    case explodedMine
    case wrongFlag

    init(_ cell: Cell, at coord: Coord, status: GameStatus, isPressed: Bool) {
        if case .lost(let exploded) = status {
            if coord == exploded { self = .explodedMine; return }
            if cell.isMine && cell.state != .flagged { self = .mine; return }
            if !cell.isMine && cell.state == .flagged { self = .wrongFlag; return }
        }
        switch cell.state {
        case .revealed: self = .revealed(cell.adjacentMines)
        case .flagged: self = .flagged
        case .hidden: self = isPressed ? .pressed : .hidden
        }
    }
}

extension Game {
    func visuals(pressed: Set<Coord>) -> [CellVisual] {
        board.cells.indices.map { i in
            let coord = board.coord(at: i)
            return CellVisual(board.cells[i], at: coord, status: status, isPressed: pressed.contains(coord))
        }
    }
}
