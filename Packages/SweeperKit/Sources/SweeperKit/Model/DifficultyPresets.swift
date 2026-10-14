/// A board is picked as shape × size × level. Shape and size set the dimensions; level sets
/// the mine density (the densities of the classic Beginner, Intermediate and Expert boards).
extension Difficulty {
    public enum Shape: CaseIterable, Hashable, Sendable {
        case square
        /// Tall and narrow, so a portrait phone pans mostly up and down.
        case rectangle
    }

    public enum Size: CaseIterable, Hashable, Sendable {
        case small, medium, large, extraLarge, massive
    }

    public enum Level: CaseIterable, Hashable, Sendable {
        case easy, medium, hard

        public var density: Double {
            switch self {
            case .easy: 10.0 / 81
            case .medium: 40.0 / 256
            case .hard: 99.0 / 480
            }
        }
    }

    public static func dimensions(_ shape: Shape, _ size: Size) -> (width: Int, height: Int) {
        switch (shape, size) {
        case (.square, .small): (12, 12)
        case (.square, .medium): (24, 24)
        case (.square, .large): (36, 36)
        case (.square, .extraLarge): (48, 48)
        case (.square, .massive): (100, 100)
        case (.rectangle, .small): (8, 16)
        case (.rectangle, .medium): (16, 32)
        case (.rectangle, .large): (24, 48)
        case (.rectangle, .extraLarge): (36, 62)
        case (.rectangle, .massive): (60, 140)
        }
    }

    public init(shape: Shape, size: Size, level: Level) {
        let dimensions = Self.dimensions(shape, size)
        self = Difficulty.custom(width: dimensions.width, height: dimensions.height, mines: 0).with(level: level)
    }

    public var density: Double { Double(mines) / Double(cellCount) }

    /// The preset shape these dimensions match, if any.
    public var shape: Shape? { preset?.shape }

    /// The preset size these dimensions match, if any.
    public var size: Size? { preset?.size }

    /// The preset level this mine count matches for these dimensions, if any.
    public var level: Level? {
        Level.allCases.first { with(level: $0).mines == mines }
    }

    /// Same size and density, other shape. A custom board becomes medium.
    public func with(shape: Shape) -> Difficulty {
        resized(to: Self.dimensions(shape, size ?? .medium))
    }

    /// Same shape and density, other size. A custom board keeps its squareness.
    public func with(size: Size) -> Difficulty {
        resized(to: Self.dimensions(shape ?? (width == height ? .square : .rectangle), size))
    }

    /// Same dimensions with a preset mine density.
    public func with(level: Level) -> Difficulty {
        .custom(width: width, height: height, mines: Int((Double(cellCount) * level.density).rounded()))
    }

    private var preset: (shape: Shape, size: Size)? {
        for shape in Shape.allCases {
            for size in Size.allCases where Self.dimensions(shape, size) == (width, height) {
                return (shape, size)
            }
        }
        return nil
    }

    /// New dimensions keeping the level, or the exact density for a custom mine count.
    private func resized(to dimensions: (width: Int, height: Int)) -> Difficulty {
        let resized = Difficulty.custom(width: dimensions.width, height: dimensions.height, mines: 0)
        if let level { return resized.with(level: level) }
        return .custom(
            width: dimensions.width,
            height: dimensions.height,
            mines: Int((Double(resized.cellCount) * density).rounded())
        )
    }
}
