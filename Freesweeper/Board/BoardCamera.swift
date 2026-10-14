import SwiftUI

/// Where the board is zoomed and scrolled to. Written by the scroll view every frame and
/// read only by the Canvas, so panning re-renders just the drawing, not the whole screen.
@MainActor @Observable
final class BoardCamera {
    struct State: Equatable {
        var zoomScale: CGFloat = 1
        /// Scroll offset in zoomed coordinates (negative while a zoomed-out board is centred).
        var offset: CGPoint = .zero
    }

    var state = State()
}
