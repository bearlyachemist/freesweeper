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
            BoardCanvas(visuals: visuals, layout: layout, camera: camera)
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
    let layout: BoardLayout
    let camera: BoardCamera

    @Environment(\.theme) private var theme
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let state = camera.state
        let renderer = theme.renderer
        let scale = displayScale
        Canvas { context, size in
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
        }
    }
}
