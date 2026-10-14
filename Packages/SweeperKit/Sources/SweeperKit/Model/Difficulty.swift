/// Board dimensions and mine count.
public struct Difficulty: Hashable, Sendable, Codable {
    /// Every board the app can play, presets included (Massive Rectangle is 140 tall).
    public static let sizeRange = 8...140
    /// What the Custom screen offers.
    public static let customSizeRange = 8...128

    public let width: Int
    public let height: Int
    public let mines: Int

    /// Unchecked. Use `custom(width:height:mines:)` for user input.
    public init(width: Int, height: Int, mines: Int) {
        self.width = width
        self.height = height
        self.mines = mines
    }

    /// Clamps to `sizeRange` and to a mine count that leaves room for a 3×3 opening.
    public static func custom(width: Int, height: Int, mines: Int) -> Difficulty {
        let width = width.clamped(to: sizeRange)
        let height = height.clamped(to: sizeRange)
        return Difficulty(
            width: width,
            height: height,
            mines: mines.clamped(to: 1...maxMines(width: width, height: height))
        )
    }

    /// Leaves room for the 3×3 safe area around the first tap.
    public static func maxMines(width: Int, height: Int) -> Int {
        max(1, width * height - 9)
    }

    public var cellCount: Int { width * height }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
