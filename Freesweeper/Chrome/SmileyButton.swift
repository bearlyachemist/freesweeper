import SwiftUI

enum SmileyFace {
    case normal
    /// A finger is down on the board.
    case pressing
    case won
    case lost
}

/// The face button: shows game state and starts a new game when tapped.
struct SmileyButton: View {
    let face: SmileyFace
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SmileyFaceView(face: face)
                .frame(width: 26, height: 26)
        }
        .buttonStyle(HeaderButtonStyle())
        .accessibilityLabel("New game")
    }
}

struct SmileyFaceView: View {
    let face: SmileyFace

    @Environment(\.theme) private var theme

    var body: some View {
        let palette = theme.palette
        Canvas { context, size in
            let d = min(size.width, size.height)
            let point = { (x: CGFloat, y: CGFloat) in CGPoint(x: x * d, y: y * d) }
            let ink = GraphicsContext.Shading.color(palette.smileyInk)
            let line = d * 0.07

            let head = Path(ellipseIn: CGRect(x: 0, y: 0, width: d, height: d).insetBy(dx: line / 2, dy: line / 2))
            context.fill(head, with: .color(palette.smiley))
            context.stroke(head, with: ink, lineWidth: line)

            // Eyes
            let eyes = [point(0.35, 0.38), point(0.65, 0.38)]
            switch face {
            case .normal, .pressing:
                for eye in eyes {
                    let r = d * 0.065
                    context.fill(Path(ellipseIn: CGRect(x: eye.x - r, y: eye.y - r, width: r * 2, height: r * 2)), with: ink)
                }
            case .won:
                let r = d * 0.12
                for eye in eyes {
                    context.fill(Path(ellipseIn: CGRect(x: eye.x - r, y: eye.y - r * 0.8, width: r * 2, height: r * 1.6)), with: ink)
                }
                let bridge = Path { p in
                    p.move(to: point(0.12, 0.33)); p.addLine(to: point(0.88, 0.33))
                }
                context.stroke(bridge, with: ink, lineWidth: line)
            case .lost:
                let r = d * 0.075
                let crosses = Path { p in
                    for eye in eyes {
                        p.move(to: CGPoint(x: eye.x - r, y: eye.y - r)); p.addLine(to: CGPoint(x: eye.x + r, y: eye.y + r))
                        p.move(to: CGPoint(x: eye.x - r, y: eye.y + r)); p.addLine(to: CGPoint(x: eye.x + r, y: eye.y - r))
                    }
                }
                context.stroke(crosses, with: ink, lineWidth: line * 0.8)
            }

            // Mouth
            let mouth: Path = switch face {
            case .normal, .won:
                Path { p in
                    p.move(to: point(0.28, 0.6))
                    p.addQuadCurve(to: point(0.72, 0.6), control: point(0.5, 0.82))
                }
            case .pressing:
                Path(ellipseIn: CGRect(origin: point(0.41, 0.58), size: CGSize(width: d * 0.18, height: d * 0.18)))
            case .lost:
                Path { p in
                    p.move(to: point(0.3, 0.76))
                    p.addQuadCurve(to: point(0.7, 0.76), control: point(0.5, 0.56))
                }
            }
            context.stroke(mouth, with: ink, style: StrokeStyle(lineWidth: line, lineCap: .round))
        }
    }
}
