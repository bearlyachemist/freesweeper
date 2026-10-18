import SwiftUI

extension Theme {
    static let modernLight = Theme(
        palette: .modernLight,
        chrome: .modern,
        renderer: ModernCellRenderer(palette: .modernLight)
    )

    static let modernDark = Theme(
        palette: .modernDark,
        chrome: .modern,
        renderer: ModernCellRenderer(palette: .modernDark)
    )
}

extension Palette {
    /// Cool gray tiles on an off-white page; revealed cells go white.
    static let modernLight = Palette(
        background: Color(hex: 0xF2F4F7),
        face: Color(hex: 0xC5D0DE),
        revealed: .white,
        pressed: Color(hex: 0xE3E8EF),
        exploded: Color(hex: 0xF0524A),
        numbers: [0x2F6BEF, 0x1F9D63, 0xE5484D, 0x7C4DDB, 0xD9731A, 0x0E9AAE, 0x1F2937, 0x8A94A3]
            .map(Color.init(hex:)),
        ink: Color(hex: 0x1F2937),
        mine: Color(hex: 0x1F2937),
        mineHighlight: .white,
        flag: Color(hex: 0xF0524A),
        wrongMark: Color(hex: 0xF0524A),
        smiley: Color(hex: 0xFFD23F),
        smileyInk: Color(hex: 0x4A3A00),
        accent: Color(hex: 0x2F6BEF),
        onAccent: .white,
        buttonFill: Color(hex: 0xE2E7EE)
    )

    /// Slate tiles on near-black; revealed cells sink darker so numbers glow.
    static let modernDark = Palette(
        background: Color(hex: 0x0F1115),
        face: Color(hex: 0x323A47),
        revealed: Color(hex: 0x1A1E25),
        pressed: Color(hex: 0x262C35),
        exploded: Color(hex: 0xE5484D),
        numbers: [0x6EA8FE, 0x4ADE80, 0xFF6B6B, 0xB197FC, 0xFBBF24, 0x2DD4BF, 0xE5E7EB, 0x9CA3AF]
            .map(Color.init(hex:)),
        ink: Color(hex: 0xE5E7EB),
        mine: Color(hex: 0xE5E7EB),
        mineHighlight: Color(hex: 0x1A1E25),
        flag: Color(hex: 0xFF6B5E),
        wrongMark: Color(hex: 0xFF6B5E),
        smiley: Color(hex: 0xF5C84C),
        smileyInk: Color(hex: 0x3A2E00),
        accent: Color(hex: 0x6E9BFF),
        onAccent: Color(hex: 0x0F1115),
        buttonFill: Color(hex: 0x1F242C)
    )
}

/// Flat rounded tiles with gaps between them, rounded numbers, and simple flag and mine glyphs.
struct ModernCellRenderer: CellRenderer {
    let palette: Palette

    /// What a cell paints, bottom to top. See `PaintBatch`.
    private enum Layer: CaseIterable {
        case face, pressed, revealed, exploded
        case flagPole, flagPennant, fadedFlagPole, fadedFlagPennant
        case mineSpikes, mineBody, mineGlint, explodedSpikes, explodedBody, explodedGlint, slash
    }

    /// A wrong flag's flag shows faded under the slash.
    private static let fadedFlagOpacity = 0.45

    func draw(_ board: BoardDrawing, in context: GraphicsContext) {
        let s = board.cellSize
        let gap = max(1, (s * 0.08 * board.displayScale).rounded() / board.displayScale)
        let radius = s * 0.2
        let font = Font.system(size: s * 0.56, weight: .bold, design: .rounded)
        let numbers = (1...8).map { n in
            context.resolve(Text("\(n)").font(font).foregroundStyle(palette.numbers[n - 1]))
        }
        var batch = PaintBatch<Layer>()
        var texts: [(number: Int, at: CGPoint)] = []

        for row in board.visibleRows {
            for column in board.visibleColumns {
                let rect = board.rect(column: column, row: row).insetBy(dx: gap / 2, dy: gap / 2)
                let tile = Path(roundedRect: rect, cornerRadius: radius, style: .continuous)
                let center = CGPoint(x: rect.midX, y: rect.midY)
                switch board.visual(column: column, row: row) {
                case .hidden:
                    batch.fill(tile, in: .face)
                case .pressed:
                    batch.fill(tile, in: .pressed)
                case .flagged:
                    batch.fill(tile, in: .face)
                    addFlag(in: rect, pole: .flagPole, pennant: .flagPennant, to: &batch)
                case .revealed(let n):
                    batch.fill(tile, in: .revealed)
                    if n > 0 { texts.append((n, center)) }
                case .mine:
                    batch.fill(tile, in: .revealed)
                    addMine(in: rect, spikes: .mineSpikes, body: .mineBody, glint: .mineGlint, to: &batch)
                case .explodedMine:
                    batch.fill(tile, in: .exploded)
                    addMine(in: rect, spikes: .explodedSpikes, body: .explodedBody, glint: .explodedGlint, to: &batch)
                case .wrongFlag:
                    batch.fill(tile, in: .revealed)
                    addFlag(in: rect, pole: .fadedFlagPole, pennant: .fadedFlagPennant, to: &batch)
                    addSlash(in: rect, to: &batch)
                }
            }
        }

        batch.draw(in: context, color: color(of:))
        // Numbers never share a cell with a glyph, so drawing them last keeps every cell's order.
        for text in texts { context.draw(numbers[text.number - 1], at: text.at) }
    }

    private func color(of layer: Layer) -> Color {
        switch layer {
        case .face: palette.face
        case .pressed: palette.pressed
        case .revealed: palette.revealed
        case .exploded: palette.exploded
        case .flagPole: palette.ink.opacity(0.8)
        case .flagPennant: palette.flag
        case .fadedFlagPole: palette.ink.opacity(0.8 * Self.fadedFlagOpacity)
        case .fadedFlagPennant: palette.flag.opacity(Self.fadedFlagOpacity)
        case .mineSpikes, .mineBody: palette.mine
        case .mineGlint: palette.mineHighlight.opacity(0.8)
        case .explodedSpikes, .explodedBody: .white
        case .explodedGlint: palette.exploded.opacity(0.8)
        case .slash: palette.wrongMark
        }
    }

    private func addMine(in rect: CGRect, spikes: Layer, body: Layer, glint: Layer, to batch: inout PaintBatch<Layer>) {
        let s = rect.width
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let spikePath = Path { p in
            for i in 0..<8 {
                let angle = Double(i) * .pi / 4
                let inner = s * 0.14, outer = s * 0.3
                p.move(to: CGPoint(x: c.x + cos(angle) * inner, y: c.y + sin(angle) * inner))
                p.addLine(to: CGPoint(x: c.x + cos(angle) * outer, y: c.y + sin(angle) * outer))
            }
        }
        batch.stroke(spikePath, style: StrokeStyle(lineWidth: max(1, s * 0.07), lineCap: .round), in: spikes)
        let r = s * 0.19
        batch.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), in: body)
        let size = r * 0.5
        batch.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.55, y: c.y - r * 0.55, width: size, height: size)), in: glint)
    }

    private func addFlag(in rect: CGRect, pole: Layer, pennant: Layer, to batch: inout PaintBatch<Layer>) {
        let s = rect.width
        let poleX = rect.minX + s * 0.36
        let top = rect.minY + s * 0.22
        let bottom = rect.minY + s * 0.78
        let polePath = Path { p in
            p.move(to: CGPoint(x: poleX, y: top))
            p.addLine(to: CGPoint(x: poleX, y: bottom))
        }
        batch.stroke(polePath, style: StrokeStyle(lineWidth: max(1, s * 0.07), lineCap: .round), in: pole)
        let pennantPath = Path { p in
            p.move(to: CGPoint(x: poleX, y: top))
            p.addQuadCurve(
                to: CGPoint(x: poleX + s * 0.36, y: top + s * 0.14),
                control: CGPoint(x: poleX + s * 0.2, y: top - s * 0.03)
            )
            p.addQuadCurve(
                to: CGPoint(x: poleX, y: top + s * 0.3),
                control: CGPoint(x: poleX + s * 0.16, y: top + s * 0.3)
            )
            p.closeSubpath()
        }
        batch.fill(pennantPath, in: pennant)
    }

    private func addSlash(in rect: CGRect, to batch: inout PaintBatch<Layer>) {
        let inset = rect.insetBy(dx: rect.width * 0.2, dy: rect.height * 0.2)
        let slash = Path { p in
            p.move(to: CGPoint(x: inset.minX, y: inset.maxY))
            p.addLine(to: CGPoint(x: inset.maxX, y: inset.minY))
        }
        batch.stroke(slash, style: StrokeStyle(lineWidth: max(1.5, rect.width * 0.09), lineCap: .round), in: .slash)
    }
}
