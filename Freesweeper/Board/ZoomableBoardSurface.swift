import SwiftUI
import UIKit
import SweeperKit

/// A transparent UIScrollView over the board that provides native pinch-zoom, panning,
/// inertia and bounce, plus tap / long-press / press tracking on the cells.
///
/// It never displays the board itself: it reports its zoom and offset and the SwiftUI Canvas
/// underneath redraws at that exact scale, so cells stay crisp at every zoom level instead of
/// being a scaled-up bitmap.
struct ZoomableBoardSurface: UIViewRepresentable {
    let layout: BoardLayout
    let longPressDuration: TimeInterval
    let onTap: @MainActor (Coord) -> Void
    let onLongPress: @MainActor (Coord) -> Void
    let onPress: @MainActor (Coord?) -> Void
    let onCameraChange: @MainActor (BoardCamera.State) -> Void

    func makeUIView(context: Context) -> BoardScrollView {
        BoardScrollView()
    }

    func updateUIView(_ view: BoardScrollView, context: Context) {
        let touch = view.touchView
        touch.columns = layout.columns
        touch.rows = layout.rows
        touch.cellSize = layout.fitCell
        touch.longPress.minimumPressDuration = longPressDuration
        touch.onTap = onTap
        touch.onLongPress = onLongPress
        touch.onPress = onPress
        view.onCameraChange = onCameraChange
        view.configure(.init(
            contentSize: layout.contentSize,
            maximumZoom: layout.maximumZoom,
            initialZoom: layout.initialZoom
        ))
    }
}

final class BoardScrollView: UIScrollView, UIScrollViewDelegate {
    struct Configuration: Equatable {
        var contentSize: CGSize
        var maximumZoom: CGFloat
        var initialZoom: CGFloat
    }

    /// The zoomed view. Its own coordinates stay unscaled, so touch locations map to cells
    /// at `fitCell` regardless of zoom.
    let touchView = BoardTouchView()
    var onCameraChange: (@MainActor (BoardCamera.State) -> Void)?

    private var configuration: Configuration?
    private var needsReset = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        delegate = self
        backgroundColor = .clear
        contentInsetAdjustmentBehavior = .never
        bouncesZoom = true
        alwaysBounceVertical = false
        alwaysBounceHorizontal = false
        minimumZoomScale = 1
        addSubview(touchView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// A new board size or screen size resets zoom; a new game on the same board keeps it.
    func configure(_ configuration: Configuration) {
        guard configuration != self.configuration else { return }
        self.configuration = configuration
        needsReset = true
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if needsReset, let configuration, bounds.width > 0, bounds.height > 0 {
            needsReset = false
            reset(to: configuration)
        }
        centerContent()
    }

    private func reset(to configuration: Configuration) {
        zoomScale = 1
        maximumZoomScale = configuration.maximumZoom
        touchView.frame = CGRect(origin: .zero, size: configuration.contentSize)
        contentSize = configuration.contentSize
        zoomScale = min(configuration.initialZoom, configuration.maximumZoom)
        centerContent()
        // Start looking at the middle of the board.
        contentOffset = CGPoint(
            x: contentSize.width > bounds.width ? (contentSize.width - bounds.width) / 2 : -contentInset.left,
            y: contentSize.height > bounds.height ? (contentSize.height - bounds.height) / 2 : -contentInset.top
        )
        reportCamera()
    }

    /// Keeps a board smaller than the viewport (zoomed out) centred rather than top-left.
    private func centerContent() {
        let dx = max(0, (bounds.width - contentSize.width) / 2)
        let dy = max(0, (bounds.height - contentSize.height) / 2)
        let insets = UIEdgeInsets(top: dy, left: dx, bottom: dy, right: dx)
        if contentInset != insets { contentInset = insets }
    }

    private func reportCamera() {
        onCameraChange?(.init(zoomScale: zoomScale, offset: contentOffset))
    }

    // MARK: UIScrollViewDelegate

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { touchView }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerContent()
        reportCamera()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        reportCamera()
    }
}

/// Turns touches into cell actions. Panning or pinching cancels these touches, which
/// clears the pressed-cell highlight.
final class BoardTouchView: UIView {
    var columns = 0
    var rows = 0
    var cellSize: CGFloat = 1
    var onTap: (@MainActor (Coord) -> Void)?
    var onLongPress: (@MainActor (Coord) -> Void)?
    var onPress: (@MainActor (Coord?) -> Void)?

    let tap = UITapGestureRecognizer()
    let longPress = UILongPressGestureRecognizer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isMultipleTouchEnabled = false

        tap.addTarget(self, action: #selector(handleTap(_:)))
        longPress.addTarget(self, action: #selector(handleLongPress(_:)))
        longPress.allowableMovement = 12
        // A tap only fires once the finger lifts before the long-press threshold.
        tap.require(toFail: longPress)
        addGestureRecognizer(tap)
        addGestureRecognizer(longPress)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func coord(at point: CGPoint) -> Coord? {
        guard cellSize > 0, point.x >= 0, point.y >= 0 else { return nil }
        let coord = Coord(x: Int(point.x / cellSize), y: Int(point.y / cellSize))
        return coord.x < columns && coord.y < rows ? coord : nil
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let coord = coord(at: recognizer.location(in: self)) else { return }
        onTap?(coord)
    }

    @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began, let coord = coord(at: recognizer.location(in: self)) else { return }
        onPress?(nil)
        onLongPress?(coord)
    }

    // Raw touches drive the pressed-cell highlight and the smiley's "o" face.

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        onPress?(touches.first.flatMap { coord(at: $0.location(in: self)) })
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        onPress?(touches.first.flatMap { coord(at: $0.location(in: self)) })
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        onPress?(nil)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        onPress?(nil)
    }
}
