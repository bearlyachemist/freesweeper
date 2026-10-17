import CoreGraphics
import Testing
import SweeperKit
@testable import Freesweeper

struct FormattingTests {
    @Test func gameTime() {
        #expect(formatGameTime(0) == "0.0 s")
        #expect(formatGameTime(42.34) == "42.3 s")
        #expect(formatGameTime(125.4) == "2:05.4")
    }

    @Test func boardNames() {
        let preset = Difficulty(shape: .rectangle, size: .extraLarge, level: .hard)
        #expect(preset.modeName == "X-Large Rectangle · Hard")
        #expect(Difficulty(width: 8, height: 8, mines: 1).summary == "8 × 8 · 1 mine")
        #expect(Difficulty(width: 20, height: 20, mines: 30).modeName == "Custom 20 × 20 · 30 mines")
        // A preset size with a custom mine count names the count instead of a level.
        #expect(Difficulty(width: 12, height: 12, mines: 1).modeName == "Small Square · 1 mine")
    }

    @Test func statsModeNameMarksNoGuessing() {
        let difficulty = Difficulty(shape: .square, size: .small, level: .easy)
        #expect(StatsMode(difficulty: difficulty, noGuessing: .easy).name == "Small Square · Easy · No Guessing (Easy)")
        #expect(StatsMode(difficulty: difficulty, noGuessing: .hard).name == "Small Square · Easy · No Guessing (Hard)")
        #expect(StatsMode(difficulty: difficulty, noGuessing: nil).name == "Small Square · Easy")
    }
}

struct LEDCounterTests {
    @Test(arguments: [
        (7, 3, "007"),
        (-7, 3, "-07"),
        (1_500, 3, "999"),
        (-500, 3, "-99"),
        (123, 5, "00123"),
        (999_999, 5, "99999"),
    ])
    func characters(value: Int, digits: Int, expected: String) {
        #expect(String(LEDCounter.characters(for: value, digits: digits)) == expected)
    }
}

struct CellVisualTests {
    @Test func duringPlay() {
        var game = Game(board: Board(width: 3, height: 3, mines: [Coord(x: 0, y: 0)]))
        game.reveal(Coord(x: 1, y: 1))
        game.toggleFlag(Coord(x: 2, y: 2))
        let visuals = game.visuals(pressed: [Coord(x: 1, y: 0)])
        #expect(visuals[0] == .hidden)
        #expect(visuals[1] == .pressed)
        #expect(visuals[4] == .revealed(1))
        #expect(visuals[8] == .flagged)
    }

    @Test func afterALoss() {
        // Mines at the two top corners; one is flagged correctly, a safe cell is flagged wrongly.
        var game = Game(board: Board(width: 3, height: 3, mines: [Coord(x: 0, y: 0), Coord(x: 2, y: 0)]))
        game.toggleFlag(Coord(x: 2, y: 0))
        game.toggleFlag(Coord(x: 2, y: 2))
        game.reveal(Coord(x: 0, y: 0))
        let visuals = game.visuals(pressed: [])
        #expect(visuals[0] == .explodedMine)
        #expect(visuals[2] == .flagged, "A correct flag stays a flag")
        #expect(visuals[8] == .wrongFlag)
        #expect(visuals[4] == .hidden)
    }
}

struct BoardLayoutTests {
    let screen = CGSize(width: 430, height: 700)

    @Test func smallBoardFitsWithoutZoom() {
        let layout = BoardLayout(columns: 12, rows: 12, available: screen)
        #expect(layout.initialZoom == 1)
        #expect(layout.viewport.width <= screen.width)
        #expect(layout.fitCell * 12 <= screen.width)
        #expect(layout.maximumZoom >= 1)
    }

    @Test func bigBoardStartsZoomedToATappableSize() {
        let layout = BoardLayout(columns: 64, rows: 64, available: screen)
        #expect(layout.initialCell == BoardLayout.comfortableCell)
        #expect(layout.initialZoom > 1)
        #expect(layout.viewport == screen)
        #expect(layout.fitCell * layout.maximumZoom <= BoardLayout.maxCell + 0.001)
    }

    @Test func narrowBoardFillsTheWidth() {
        let layout = BoardLayout(columns: 8, rows: 16, available: screen)
        #expect(layout.initialCell <= BoardLayout.maxCell)
        #expect(layout.viewport.width <= screen.width)
    }
}

struct BoardDrawingTests {
    func drawing(cellSize: CGFloat, visible: CGRect) -> BoardDrawing {
        BoardDrawing(
            cells: Array(repeating: .hidden, count: 100),
            columns: 10,
            rows: 10,
            cellSize: cellSize,
            displayScale: 3,
            visibleRect: visible
        )
    }

    @Test func onlyVisibleCellsAreDrawn() {
        let board = drawing(cellSize: 30, visible: CGRect(x: 45, y: 0, width: 60, height: 300))
        #expect(board.visibleColumns == 1..<4)
        #expect(board.visibleRows == 0..<10)
    }

    @Test func offscreenRangesAreEmpty() {
        let board = drawing(cellSize: 30, visible: CGRect(x: 500, y: 500, width: 60, height: 60))
        #expect(board.visibleColumns.isEmpty)
    }

    @Test func cellsMeetOnPixelBoundaries() {
        let board = drawing(cellSize: 23.37, visible: .zero)
        for column in 0..<9 {
            let left = board.rect(column: column, row: 0)
            let right = board.rect(column: column + 1, row: 0)
            #expect(left.maxX == right.minX, "No seams or overlaps between neighbours")
            #expect((left.minX * 3).rounded() == left.minX * 3, "Edges land on device pixels")
        }
    }
}
