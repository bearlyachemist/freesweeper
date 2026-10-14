import Testing
@testable import SweeperKit

struct NoGuessGeneratorTests {
    static let presets: [Difficulty] = Difficulty.Shape.allCases.flatMap { shape in
        [Difficulty.Size.small, .medium].flatMap { size in
            Difficulty.Level.allCases.map { Difficulty(shape: shape, size: size, level: $0) }
        }
    }

    @Test(arguments: presets)
    func boardsAreSolvableWithoutGuessing(difficulty: Difficulty) throws {
        for seed in UInt64(0)..<5 {
            let start = Coord(x: Int(seed) % difficulty.width, y: Int(seed * 7) % difficulty.height)
            let board = try #require(NoGuessGenerator.generate(difficulty, seed: seed, safe: start))
            #expect(board.mineCount == difficulty.mines)
            #expect(!board[start].isMine)
            #expect(NoGuessGenerator.isSolvable(board, from: start))
        }
    }

    @Test func extraLargeHard() throws {
        let difficulty = Difficulty(shape: .rectangle, size: .extraLarge, level: .hard)
        let start = Coord(x: 18, y: 31)
        let board = try #require(NoGuessGenerator.generate(difficulty, seed: 1, safe: start))
        #expect(board.mineCount == difficulty.mines)
        #expect(NoGuessGenerator.isSolvable(board, from: start))
    }

    @Test func deterministic() {
        let start = Coord(x: 3, y: 3)
        let difficulty = Difficulty(shape: .square, size: .small, level: .hard)
        #expect(NoGuessGenerator.generate(difficulty, seed: 9, safe: start)
            == NoGuessGenerator.generate(difficulty, seed: 9, safe: start))
    }

    @Test func timeLimitStopsGeneration() {
        // 64×64 at ~45% mines can't be made no-guess quickly; the limit must cut it short.
        let dense = Difficulty.custom(width: 64, height: 64, mines: 1_850)
        let started = ContinuousClock.now
        let board = NoGuessGenerator.generate(dense, seed: 1, safe: Coord(x: 32, y: 32), timeLimit: .milliseconds(300))
        #expect(board == nil)
        #expect(ContinuousClock.now - started < .seconds(2))
    }

    @Test func cancellationStopsGeneration() async {
        let dense = Difficulty.custom(width: 64, height: 64, mines: 1_850)
        let task = Task.detached {
            NoGuessGenerator.generate(dense, seed: 1, safe: Coord(x: 32, y: 32))
        }
        try? await Task.sleep(for: .milliseconds(100))
        let started = ContinuousClock.now
        task.cancel()
        let board = await task.value
        #expect(board == nil)
        #expect(ContinuousClock.now - started < .seconds(2))
    }

    @Test func startOutsideBoardFailsSafely() {
        #expect(NoGuessGenerator.generate(.beginner, seed: 1, safe: Coord(x: 40, y: 40)) == nil)
    }
}
