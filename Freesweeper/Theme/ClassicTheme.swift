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

    func draw(_ board: BoardDrawing, in context: GraphicsContext) {
        let s = board.cellSize
        let font = Font.system(size: s * 0.66, weight: .heavy, design: .rounded)
        let numbers = (1...8).map { n in
            context.resolve(Text("\(n)").font(font).foregroundStyle(palette.numbers[n - 1]))
        }
        let bevel = max(1.5, (s / 10).rounded())

        for row in board.visibleRows {
            for column in board.visibleColumns {
                let rect = board.rect(column: column, row: row)
                let center = CGPoint(x: rect.midX, y: rect.midY)
                switch board.visual(column: column, row: row) {
                case .hidden:
                    drawRaised(rect, bevel: bevel, in: context)
                case .flagged:
                    drawRaised(rect, bevel: bevel, in: context)
                    drawFlag(in: rect, context: context)
                case .pressed:
                    drawFlat(rect, fill: palette.pressed, in: context)
                case .revealed(let n):
                    drawFlat(rect, fill: palette.revealed, in: context)
                    if n > 0 { context.draw(numbers[n - 1], at: center) }
                case .mine:
                    drawFlat(rect, fill: palette.revealed, in: context)
                    drawMine(in: rect, context: context)
                case .explodedMine:
                    drawFlat(rect, fill: palette.exploded, in: context)
                    drawMine(in: rect, context: context)
                case .wrongFlag:
                    drawFlat(rect, fill: palette.revealed, in: context)
                    drawMine(in: rect, context: context)
                    drawCross(in: rect, context: context)
                }
            }
        }

        // Cells only draw their top/left grid lines, so close the board's right and bottom edges.
        let edge = board.rect(column: board.columns - 1, row: board.rows - 1)
        let line = GraphicsContext.Shading.color(colors.gridLine)
        context.fill(Path(CGRect(x: edge.maxX - 1, y: 0, width: 1, height: edge.maxY)), with: line)
        context.fill(Path(CGRect(x: 0, y: edge.maxY - 1, width: edge.maxX, height: 1)), with: line)
    }

    private func drawRaised(_ rect: CGRect, bevel: CGFloat, in context: GraphicsContext) {
        context.fill(Path(rect), with: .color(palette.face))
        context.fill(BevelGeometry.topLeading(rect, width: bevel), with: .color(colors.bevelLight))
        context.fill(BevelGeometry.bottomTrailing(rect, width: bevel), with: .color(colors.bevelDark))
    }

    /// Flat fill with a grid line on the top and left (`draw` closes the board's far edges).
    private func drawFlat(_ rect: CGRect, fill: Color, in context: GraphicsContext) {
        context.fill(Path(rect), with: .color(fill))
        context.fill(Path(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 1)), with: .color(colors.gridLine))
        context.fill(Path(CGRect(x: rect.minX, y: rect.minY, width: 1, height: rect.height)), with: .color(colors.gridLine))
    }

    private func drawMine(in rect: CGRect, context: GraphicsContext) {
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
        context.stroke(spikes, with: .color(palette.mine), lineWidth: max(1, s * 0.08))

        let r = s * 0.25
        context.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(palette.mine))
        let glint = r * 0.42
        context.fill(
            Path(CGRect(x: c.x - r * 0.55, y: c.y - r * 0.55, width: glint, height: glint)),
            with: .color(palette.mineHighlight)
        )
    }

    private func drawFlag(in rect: CGRect, context: GraphicsContext) {
        let s = rect.width
        let poleX = rect.minX + s * 0.56
        let top = rect.minY + s * 0.18
        let pennant = Path { p in
            p.move(to: CGPoint(x: poleX, y: top))
            p.addLine(to: CGPoint(x: poleX, y: top + s * 0.32))
            p.addLine(to: CGPoint(x: rect.minX + s * 0.22, y: top + s * 0.16))
            p.closeSubpath()
        }
        context.fill(pennant, with: .color(palette.flag))
        let ink = GraphicsContext.Shading.color(palette.ink)
        context.fill(Path(CGRect(x: poleX - s * 0.035, y: top, width: s * 0.07, height: s * 0.54)), with: ink)
        context.fill(Path(CGRect(x: rect.minX + s * 0.36, y: rect.minY + s * 0.66, width: s * 0.36, height: s * 0.07)), with: ink)
        context.fill(Path(CGRect(x: rect.minX + s * 0.24, y: rect.minY + s * 0.72, width: s * 0.6, height: s * 0.09)), with: ink)
    }

    private func drawCross(in rect: CGRect, context: GraphicsContext) {
        let inset = rect.insetBy(dx: rect.width * 0.16, dy: rect.height * 0.16)
        let cross = Path { p in
            p.move(to: CGPoint(x: inset.minX, y: inset.minY)); p.addLine(to: CGPoint(x: inset.maxX, y: inset.maxY))
            p.move(to: CGPoint(x: inset.minX, y: inset.maxY)); p.addLine(to: CGPoint(x: inset.maxX, y: inset.minY))
        }
        context.stroke(cross, with: .color(palette.wrongMark), lineWidth: max(1.5, rect.width * 0.09))
    }
}
