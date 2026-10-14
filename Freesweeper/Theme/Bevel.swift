import SwiftUI

enum BevelStyle {
    case raised
    case sunken
}

/// The two L-shaped edges of a 3D bevel, mitred at the corners.
enum BevelGeometry {
    static func topLeading(_ r: CGRect, width b: CGFloat) -> Path {
        Path { p in
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX - b, y: r.minY + b))
            p.addLine(to: CGPoint(x: r.minX + b, y: r.minY + b))
            p.addLine(to: CGPoint(x: r.minX + b, y: r.maxY - b))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            p.closeSubpath()
        }
    }

    static func bottomTrailing(_ r: CGRect, width b: CGFloat) -> Path {
        Path { p in
            p.move(to: CGPoint(x: r.maxX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX + b, y: r.maxY - b))
            p.addLine(to: CGPoint(x: r.maxX - b, y: r.maxY - b))
            p.addLine(to: CGPoint(x: r.maxX - b, y: r.minY + b))
            p.closeSubpath()
        }
    }
}

private struct BevelModifier: ViewModifier {
    let style: BevelStyle
    let width: CGFloat
    let colors: ClassicColors

    func body(content: Content) -> some View {
        let (topLeading, bottomTrailing) = style == .raised
            ? (colors.bevelLight, colors.bevelDark)
            : (colors.bevelDark, colors.bevelLight)
        content
            .padding(width)
            .overlay {
                Canvas { context, size in
                    let rect = CGRect(origin: .zero, size: size)
                    context.fill(BevelGeometry.topLeading(rect, width: width), with: .color(topLeading))
                    context.fill(BevelGeometry.bottomTrailing(rect, width: width), with: .color(bottomTrailing))
                }
                .allowsHitTesting(false)
            }
    }
}

extension View {
    /// Pads the view by `width` and draws a raised or sunken classic 3D edge in that space.
    func bevel(_ style: BevelStyle, width: CGFloat, colors: ClassicColors) -> some View {
        modifier(BevelModifier(style: style, width: width, colors: colors))
    }
}
