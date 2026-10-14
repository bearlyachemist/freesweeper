import Testing
@testable import SweeperKit

struct DifficultyPresetTests {
    @Test func dimensions() {
        #expect(Difficulty(shape: .square, size: .extraLarge, level: .easy).width == 48)
        let tall = Difficulty(shape: .rectangle, size: .extraLarge, level: .easy)
        #expect(tall.width == 36 && tall.height == 62)
        let massive = Difficulty(shape: .rectangle, size: .massive, level: .hard)
        #expect(massive.width == 60 && massive.height == 140, "Presets may exceed the custom cap")
        #expect(Difficulty(shape: .square, size: .massive, level: .easy).width == 100)
    }

    @Test func levelsKeepClassicDensities() {
        // 24×24 = 576 cells
        #expect(Difficulty(shape: .square, size: .medium, level: .easy).mines == 71)
        #expect(Difficulty(shape: .square, size: .medium, level: .medium).mines == 90)
        #expect(Difficulty(shape: .square, size: .medium, level: .hard).mines == 119)
    }

    @Test func presetsRoundTrip() {
        for shape in Difficulty.Shape.allCases {
            for size in Difficulty.Size.allCases {
                for level in Difficulty.Level.allCases {
                    let difficulty = Difficulty(shape: shape, size: size, level: level)
                    #expect(difficulty.shape == shape)
                    #expect(difficulty.size == size)
                    #expect(difficulty.level == level)
                }
            }
        }
    }

    @Test func changingShapeKeepsSizeAndLevel() {
        let board = Difficulty(shape: .square, size: .large, level: .hard).with(shape: .rectangle)
        #expect(board.width == 24 && board.height == 48)
        #expect(board.level == .hard)
    }

    @Test func changingSizeKeepsShapeAndLevel() {
        let board = Difficulty(shape: .rectangle, size: .small, level: .easy).with(size: .medium)
        #expect(board.shape == .rectangle && board.size == .medium)
        #expect(board.level == .easy)
    }

    @Test func changingLevelKeepsCustomSize() {
        let big = Difficulty.custom(width: 30, height: 30, mines: 100).with(level: .hard)
        #expect(big.width == 30 && big.height == 30)
        #expect(big.level == .hard)
        #expect(big.size == nil)
    }

    @Test func customBoardsPickSensibleDefaults() {
        let customSquare = Difficulty.custom(width: 20, height: 20, mines: 20) // 5%, not a preset level
        let resized = customSquare.with(size: .small)
        #expect(resized.shape == .square)
        #expect(resized.mines == 7) // 144 × 5% rounded
        #expect(customSquare.with(shape: .rectangle).size == .medium)
    }
}
