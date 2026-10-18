import SwiftUI
import SweeperKit

/// The minefield: a Canvas that draws only the visible cells at the current zoom, under a
/// transparent scroll view that handles pinch, pan and cell touches.
struct BoardView: View {
    let layout: BoardLayout

    @Environment(GameSession.self) private var session
    @Environment(AppSettings.self) private var settings
    @State private var camera = BoardCamera()

    var body: some View {
        let visuals = session.game.visuals(pressed: session.pressedCells)
        ZStack {
            BoardCanvas(visuals: visuals, hinted: session.hint?.numbers ?? [], layout: layout, camera: camera)
            ZoomableBoardSurface(
                layout: layout,
                longPressDuration: settings.longPressDuration,
                onTap: session.tap,
                onLongPress: session.longPress,
                onPress: session.press,
                onCameraChange: { [camera] state in
                    if camera.state != state { camera.state = state }
                }
            )
        }
        .frame(width: layout.viewport.width, height: layout.viewport.height)
        .clipped()
        .accessibilityElement()
        .accessibilityLabel("Minefield")
        .accessibilityHint("Pinch to zoom, drag to pan")
    }

}

private struct BoardCanvas: View {
    let visuals: [CellVisual]
    /// Numbers a hint points at, outlined with a gentle pulse.
    let hinted: Set<Coord>
    let layout: BoardLayout
    let camera: BoardCamera

    @Environment(\.theme) private var theme
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Redraws every frame only while a hint pulses.
        TimelineView(.animation(paused: hinted.isEmpty || reduceMotion)) { timeline in
            let pulse = reduceMotion ? 1 : 0.65 + 0.35 * cos(timeline.date.timeIntervalSinceReferenceDate * .pi / 0.6)
            canvas(hintOpacity: pulse)
        }
    }

    private func canvas(hintOpacity: Double) -> some View {
        let state = camera.state
        let renderer = theme.renderer
        let scale = displayScale
        let hinted = hinted
        return Canvas { context, size in
            // Snap the scroll offset to device pixels so cell edges stay sharp mid-pan.
            let origin = CGPoint(
                x: (state.offset.x * scale).rounded() / scale,
                y: (state.offset.y * scale).rounded() / scale
            )
            var context = context
            context.translateBy(x: -origin.x, y: -origin.y)
            renderer.draw(
                BoardDrawing(
                    cells: visuals,
                    columns: layout.columns,
                    rows: layout.rows,
                    cellSize: layout.fitCell * state.zoomScale,
                    displayScale: scale,
                    visibleRect: CGRect(origin: origin, size: size)
                ),
                in: context
            )
            guard !hinted.isEmpty else { return }
            let cellSize = layout.fitCell * state.zoomScale
            let lineWidth = max(2, cellSize * 0.12)
            for coord in hinted {
                let rect = CGRect(
                    x: CGFloat(coord.x) * cellSize, y: CGFloat(coord.y) * cellSize,
                    width: cellSize, height: cellSize
                ).insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
                context.stroke(
                    Path(roundedRect: rect, cornerRadius: lineWidth),
                    with: .color(Color.hint.opacity(hintOpacity)),
                    lineWidth: lineWidth
                )
            }
        }
    }
}
