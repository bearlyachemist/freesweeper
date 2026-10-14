import SwiftUI

/// Seven-segment digits drawn as polygons, so the LED counters need no font or image assets.
enum SevenSegment {
    enum Segment: CaseIterable {
        case top, topRight, bottomRight, bottom, bottomLeft, topLeft, middle
    }

    static func segments(for character: Character) -> Set<Segment> {
        switch character {
        case "0": [.top, .topRight, .bottomRight, .bottom, .bottomLeft, .topLeft]
        case "1": [.topRight, .bottomRight]
        case "2": [.top, .topRight, .middle, .bottomLeft, .bottom]
        case "3": [.top, .topRight, .middle, .bottomRight, .bottom]
        case "4": [.topLeft, .middle, .topRight, .bottomRight]
        case "5": [.top, .topLeft, .middle, .bottomRight, .bottom]
        case "6": [.top, .topLeft, .middle, .bottomLeft, .bottomRight, .bottom]
        case "7": [.top, .topRight, .bottomRight]
        case "8": Set(Segment.allCases)
        case "9": [.top, .topRight, .bottomRight, .bottom, .topLeft, .middle]
        case "-": [.middle]
        default: []
        }
    }

    /// Draws every segment: lit ones in `on`, the rest faintly in `off` like a real LED.
    static func draw(_ character: Character, in rect: CGRect, on: Color, off: Color, context: GraphicsContext) {
        let lit = segments(for: character)
        let t = rect.width * 0.2
        let gap = t * 0.3
        let left = rect.minX + t / 2, right = rect.maxX - t / 2
        let top = rect.minY + t / 2, middle = rect.midY, bottom = rect.maxY - t / 2

        for segment in Segment.allCases {
            let path: Path = switch segment {
            case .top: horizontal(y: top, from: left + gap, to: right - gap, thickness: t)
            case .middle: horizontal(y: middle, from: left + gap, to: right - gap, thickness: t)
            case .bottom: horizontal(y: bottom, from: left + gap, to: right - gap, thickness: t)
            case .topLeft: vertical(x: left, from: top + gap, to: middle - gap, thickness: t)
            case .topRight: vertical(x: right, from: top + gap, to: middle - gap, thickness: t)
            case .bottomLeft: vertical(x: left, from: middle + gap, to: bottom - gap, thickness: t)
            case .bottomRight: vertical(x: right, from: middle + gap, to: bottom - gap, thickness: t)
            }
            context.fill(path, with: .color(lit.contains(segment) ? on : off))
        }
    }

    private static func horizontal(y: CGFloat, from x0: CGFloat, to x1: CGFloat, thickness t: CGFloat) -> Path {
        Path { p in
            p.move(to: CGPoint(x: x0, y: y))
            p.addLine(to: CGPoint(x: x0 + t / 2, y: y - t / 2))
            p.addLine(to: CGPoint(x: x1 - t / 2, y: y - t / 2))
            p.addLine(to: CGPoint(x: x1, y: y))
            p.addLine(to: CGPoint(x: x1 - t / 2, y: y + t / 2))
            p.addLine(to: CGPoint(x: x0 + t / 2, y: y + t / 2))
            p.closeSubpath()
        }
    }

    private static func vertical(x: CGFloat, from y0: CGFloat, to y1: CGFloat, thickness t: CGFloat) -> Path {
        Path { p in
            p.move(to: CGPoint(x: x, y: y0))
            p.addLine(to: CGPoint(x: x + t / 2, y: y0 + t / 2))
            p.addLine(to: CGPoint(x: x + t / 2, y: y1 - t / 2))
            p.addLine(to: CGPoint(x: x, y: y1))
            p.addLine(to: CGPoint(x: x - t / 2, y: y1 - t / 2))
            p.addLine(to: CGPoint(x: x - t / 2, y: y0 + t / 2))
            p.closeSubpath()
        }
    }
}
