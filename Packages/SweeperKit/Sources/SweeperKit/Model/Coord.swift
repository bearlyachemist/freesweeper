/// A cell position. `x` is the column, `y` is the row, both zero-based from the top-left.
public struct Coord: Hashable, Sendable, Codable, CustomStringConvertible {
    public var x: Int
    public var y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    public var description: String { "(\(x), \(y))" }
}
