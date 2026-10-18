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

/// Shapes gathered per layer, so a frame costs one fill per layer instead of several per cell.
///
/// A huge board at fit zoom has 10,000+ visible cells, and a fill per shape per cell made a
/// Metal command buffer too big for the iOS Simulator, which crashed the app. Layers are filled
/// in their `allCases` order, so declare them in the order a single cell paints them. Shapes in one
/// layer are filled as one union, so they must not overlap unless they wind the same way
/// (like rects), or the overlap could come out as a hole; one shape per cell per layer is safe.
struct PaintBatch<Layer: CaseIterable & Hashable> {
    private var paths: [Layer: Path] = [:]

    mutating func fill(_ path: Path, in layer: Layer) {
        paths[layer, default: Path()].addPath(path)
    }

    mutating func fill(_ rect: CGRect, in layer: Layer) {
        paths[layer, default: Path()].addRect(rect)
    }

    /// Adds the stroke's outline, so strokes batch like fills.
    mutating func stroke(_ path: Path, style: StrokeStyle, in layer: Layer) {
        fill(path.strokedPath(style), in: layer)
    }

    func draw(in context: GraphicsContext, color: (Layer) -> Color) {
        for layer in Layer.allCases {
            if let path = paths[layer] { context.fill(path, with: .color(color(layer))) }
        }
    }
}
