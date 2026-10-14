import SwiftUI

/// Draws the board into a Canvas. One implementation per look (classic, modern…).
/// Drawing the whole visible area in one pass lets a renderer share setup like resolved glyphs.
protocol CellRenderer: Sendable {
    func draw(_ board: BoardDrawing, in context: GraphicsContext)
}

/// One frame of the board at the current zoom, in board coordinates.
struct BoardDrawing {
    let cells: [CellVisual]
    let columns: Int
    let rows: Int
    let cellSize: CGFloat
    let displayScale: CGFloat
    /// The on-screen part of the board; cells outside it are skipped.
    let visibleRect: CGRect

    var visibleColumns: Range<Int> { span(visibleRect.minX, visibleRect.maxX, count: columns) }
    var visibleRows: Range<Int> { span(visibleRect.minY, visibleRect.maxY, count: rows) }

    func visual(column: Int, row: Int) -> CellVisual {
        cells[row * columns + column]
    }

    /// The cell's rect with edges snapped to device pixels, so neighbours meet without
    /// hairline seams at fractional zoom levels.
    func rect(column: Int, row: Int) -> CGRect {
        let x0 = edge(column), x1 = edge(column + 1)
        let y0 = edge(row), y1 = edge(row + 1)
        return CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
    }

    private func edge(_ index: Int) -> CGFloat {
        (CGFloat(index) * cellSize * displayScale).rounded() / displayScale
    }

    private func span(_ low: CGFloat, _ high: CGFloat, count: Int) -> Range<Int> {
        let first = max(0, Int((low / cellSize).rounded(.down)))
        let last = min(count, Int((high / cellSize).rounded(.up)))
        return first < last ? first..<last : 0..<0
    }
}
