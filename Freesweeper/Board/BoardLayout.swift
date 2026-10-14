import CoreGraphics

/// Sizes the board for the available space.
///
/// Zoom 1 is the whole board fitted on screen (`fitCell`). A game starts zoomed in to a
/// tappable size when the fit is too small, and can be pinched out to the fit or in to `maxCell`.
struct BoardLayout: Equatable {
    /// Largest cell size when zoomed all the way in.
    static let maxCell: CGFloat = 56
    /// Starting cell size for boards too big to fit at a tappable size.
    static let comfortableCell: CGFloat = 28
    /// Narrowest cell we'll start at just to avoid sideways panning.
    static let minTappableCell: CGFloat = 20

    let columns: Int
    let rows: Int
    /// Cell size with the whole board visible (zoom scale 1).
    let fitCell: CGFloat
    let initialCell: CGFloat
    /// On-screen size of the board area.
    let viewport: CGSize

    init(columns: Int, rows: Int, available: CGSize) {
        self.columns = columns
        self.rows = rows
        let widthFit = available.width / CGFloat(columns)
        let heightFit = available.height / CGFloat(rows)
        // Not rounded: the renderer snaps cell edges to pixels, and whole points would waste
        // up to a cell's width of screen on big boards.
        fitCell = max(1, min(widthFit, heightFit, Self.maxCell))

        // Fill the width if that's tappable (no sideways panning); otherwise start comfortable and pan.
        let start = widthFit >= Self.minTappableCell ? min(widthFit, Self.comfortableCell) : Self.comfortableCell
        initialCell = min(max(fitCell, start), Self.maxCell)

        viewport = CGSize(
            width: min(initialCell * CGFloat(columns), max(available.width, 0)),
            height: min(initialCell * CGFloat(rows), max(available.height, 0))
        )
    }

    /// The board at zoom 1.
    var contentSize: CGSize { CGSize(width: fitCell * CGFloat(columns), height: fitCell * CGFloat(rows)) }
    var initialZoom: CGFloat { initialCell / fitCell }
    var maximumZoom: CGFloat { max(1, Self.maxCell / fitCell) }
}
