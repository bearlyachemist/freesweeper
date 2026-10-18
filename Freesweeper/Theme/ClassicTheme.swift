import SwiftUI

extension Theme {
    static let classicLight = Theme(
        palette: .classicLight,
        chrome: .classic(.light),
        renderer: ClassicCellRenderer(palette: .classicLight, colors: .light)
    )

    static let classicDark = Theme(
        palette: .classicDark,
        chrome: .classic(.dark),
        renderer: ClassicCellRenderer(palette: .classicDark, colors: .dark)
    )
}

extension Palette {
    /// The Windows 3.1–XP gray with the original number colors.
    static let classicLight = Palette(
        background: Color(hex: 0xC0C0C0),
        face: Color(hex: 0xC0C0C0),
        revealed: Color(hex: 0xC0C0C0),
        pressed: Color(hex: 0xC0C0C0),
        exploded: Color(hex: 0xFF0000),
        numbers: [0x0000FF, 0x008000, 0xFF0000, 0x000080, 0x800000, 0x008080, 0x000000, 0x808080]
            .map(Color.init(hex:)),
        ink: .black,
        mine: .black,
        mineHighlight: .white,
        flag: Color(hex: 0xFF0000),
        wrongMark: Color(hex: 0xFF0000),
        smiley: Color(hex: 0xFFFF00),
        smileyInk: .black,
        accent: Color(hex: 0x000080),
        onAccent: .white,
        buttonFill: Color(hex: 0xC0C0C0)
    )

    /// Same layout and bevels on charcoal, with numbers brightened to stay readable.
    static let classicDark = Palette(
        background: Color(hex: 0x262626),
        face: Color(hex: 0x3C3C3C),
        revealed: Color(hex: 0x2E2E2E),
        pressed: Color(hex: 0x2E2E2E),
        exploded: Color(hex: 0xC62828),
        numbers: [0x7AA2FF, 0x5BC76E, 0xFF6B6B, 0xB39DFF, 0xE8955F, 0x4FD1D1, 0xE6E6E6, 0x9A9A9A]
            .map(Color.init(hex:)),
        ink: Color(hex: 0xE6E6E6),
        mine: Color(hex: 0xD6D6D6),
        mineHighlight: Color(hex: 0x2E2E2E),
        flag: Color(hex: 0xFF5252),
        wrongMark: Color(hex: 0xFF5252),
        smiley: Color(hex: 0xE8C547),
        smileyInk: .black,
        accent: Color(hex: 0x8FB0FF),
        onAccent: Color(hex: 0x10131A),
        buttonFill: Color(hex: 0x3C3C3C)
    )
}

extension ClassicColors {
    static let light = ClassicColors(
        bevelLight: .white,
        bevelDark: Color(hex: 0x808080),
        gridLine: Color(hex: 0x808080),
        ledBackground: .black,
        ledOn: Color(hex: 0xFF0000),
        ledOff: Color(hex: 0x3A0000)
    )

    static let dark = ClassicColors(
        bevelLight: Color(hex: 0x666666),
        bevelDark: Color(hex: 0x161616),
        gridLine: Color(hex: 0x1C1C1C),
        ledBackground: .black,
        ledOn: Color(hex: 0xFF3B30),
        ledOff: Color(hex: 0x2A0806)
    )
}

/// Draws cells the way Windows did: raised gray tiles, flat revealed squares with a
/// one-point grid, and hand-drawn mine/flag glyphs that stay crisp at any size.
struct ClassicCellRenderer: CellRenderer {
    let palette: Palette
    let colors: ClassicColors

    /// What a cell paints, bottom to top. See `PaintBatch`.
    private enum Layer: CaseIterable {
        case face, revealed, pressed, exploded, grid, bevelLight, bevelDark
        case pennant, flagInk, mineSpikes, mineBody, mineGlint, cross
    }

    func draw(_ board: BoardDrawing, in context: GraphicsContext) {
        let s = board.cellSize
        let font = Font.system(size: s * 0.66, weight: .heavy, design: .rounded)
        let numbers = (1...8).map { n in
            context.resolve(Text("\(n)").font(font).foregroundStyle(palette.numbers[n - 1]))
        }
        let bevel = max(1.5, (s / 10).rounded())
        var batch = PaintBatch<Layer>()
        var texts: [(number: Int, at: CGPoint)] = []

        for row in board.visibleRows {
            for column in board.visibleColumns {
                let rect = board.rect(column: column, row: row)
                let center = CGPoint(x: rect.midX, y: rect.midY)
                switch board.visual(column: column, row: row) {
                case .hidden:
                    addRaised(rect, bevel: bevel, to: &batch)
                case .flagged:
                    addRaised(rect, bevel: bevel, to: &batch)
                    addFlag(in: rect, to: &batch)
                case .pressed:
                    addFlat(rect, fill: .pressed, to: &batch)
                case .revealed(let n):
                    addFlat(rect, fill: .revealed, to: &batch)
                    if n > 0 { texts.append((n, center)) }
                case .mine:
                    addFlat(rect, fill: .revealed, to: &batch)
                    addMine(in: rect, to: &batch)
                case .explodedMine:
                    addFlat(rect, fill: .exploded, to: &batch)
                    addMine(in: rect, to: &batch)
                case .wrongFlag:
                    addFlat(rect, fill: .revealed, to: &batch)
                    addMine(in: rect, to: &batch)
                    addCross(in: rect, to: &batch)
                }
            }
        }

        batch.draw(in: context, color: color(of:))
        // Numbers never share a cell with a glyph, so drawing them last keeps every cell's order.
        for text in texts { context.draw(numbers[text.number - 1], at: text.at) }

        // Cells only draw their top/left grid lines, so close the board's right and bottom edges.
        let edge = board.rect(column: board.columns - 1, row: board.rows - 1)
        let line = GraphicsContext.Shading.color(colors.gridLine)
        context.fill(Path(CGRect(x: edge.maxX - 1, y: 0, width: 1, height: edge.maxY)), with: line)
        context.fill(Path(CGRect(x: 0, y: edge.maxY - 1, width: edge.maxX, height: 1)), with: line)
    }

    private func color(of layer: Layer) -> Color {
        switch layer {
        case .face: palette.face
        case .revealed: palette.revealed
        case .pressed: palette.pressed
        case .exploded: palette.exploded
        case .grid: colors.gridLine
        case .bevelLight: colors.bevelLight
        case .bevelDark: colors.bevelDark
        case .pennant: palette.flag
        case .flagInk: palette.ink
        case .mineSpikes, .mineBody: palette.mine
        case .mineGlint: palette.mineHighlight
        case .cross: palette.wrongMark
        }
    }

    private func addRaised(_ rect: CGRect, bevel: CGFloat, to batch: inout PaintBatch<Layer>) {
        batch.fill(rect, in: .face)
        batch.fill(BevelGeometry.topLeading(rect, width: bevel), in: .bevelLight)
        batch.fill(BevelGeometry.bottomTrailing(rect, width: bevel), in: .bevelDark)
    }

    /// Flat fill with a grid line on the top and left (`draw` closes the board's far edges).
    private func addFlat(_ rect: CGRect, fill: Layer, to batch: inout PaintBatch<Layer>) {
        batch.fill(rect, in: fill)
        // The two lines overlap at the corner; same-direction rects keep it filled.
        batch.fill(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 1), in: .grid)
        batch.fill(CGRect(x: rect.minX, y: rect.minY, width: 1, height: rect.height), in: .grid)
    }

    private func addMine(in rect: CGRect, to batch: inout PaintBatch<Layer>) {
        let s = rect.width
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let long = s * 0.36
        let short = s * 0.25
        let spikes = Path { p in
            p.move(to: CGPoint(x: c.x - long, y: c.y)); p.addLine(to: CGPoint(x: c.x + long, y: c.y))
            p.move(to: CGPoint(x: c.x, y: c.y - long)); p.addLine(to: CGPoint(x: c.x, y: c.y + long))
            p.move(to: CGPoint(x: c.x - short, y: c.y - short)); p.addLine(to: CGPoint(x: c.x + short, y: c.y + short))
            p.move(to: CGPoint(x: c.x - short, y: c.y + short)); p.addLine(to: CGPoint(x: c.x + short, y: c.y - short))
        }
        batch.stroke(spikes, style: StrokeStyle(lineWidth: max(1, s * 0.08)), in: .mineSpikes)

        let r = s * 0.25
        batch.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), in: .mineBody)
        let glint = r * 0.42
        batch.fill(CGRect(x: c.x - r * 0.55, y: c.y - r * 0.55, width: glint, height: glint), in: .mineGlint)
    }

    private func addFlag(in rect: CGRect, to batch: inout PaintBatch<Layer>) {
        let s = rect.width
        let poleX = rect.minX + s * 0.56
        let top = rect.minY + s * 0.18
        let pennant = Path { p in
            p.move(to: CGPoint(x: poleX, y: top))
            p.addLine(to: CGPoint(x: poleX, y: top + s * 0.32))
            p.addLine(to: CGPoint(x: rect.minX + s * 0.22, y: top + s * 0.16))
            p.closeSubpath()
        }
        batch.fill(pennant, in: .pennant)
        // Overlapping rects all wind the same way, so their union fills solid.
        batch.fill(CGRect(x: poleX - s * 0.035, y: top, width: s * 0.07, height: s * 0.54), in: .flagInk)
        batch.fill(CGRect(x: rect.minX + s * 0.36, y: rect.minY + s * 0.66, width: s * 0.36, height: s * 0.07), in: .flagInk)
        batch.fill(CGRect(x: rect.minX + s * 0.24, y: rect.minY + s * 0.72, width: s * 0.6, height: s * 0.09), in: .flagInk)
    }

    private func addCross(in rect: CGRect, to batch: inout PaintBatch<Layer>) {
        let inset = rect.insetBy(dx: rect.width * 0.16, dy: rect.height * 0.16)
        let cross = Path { p in
            p.move(to: CGPoint(x: inset.minX, y: inset.minY)); p.addLine(to: CGPoint(x: inset.maxX, y: inset.maxY))
            p.move(to: CGPoint(x: inset.minX, y: inset.maxY)); p.addLine(to: CGPoint(x: inset.maxX, y: inset.minY))
        }
        batch.stroke(cross, style: StrokeStyle(lineWidth: max(1.5, rect.width * 0.09)), in: .cross)
    }
}
