/// A rectangular minefield stored row-major in a flat array (`index = y * width + x`).
public struct Board: Hashable, Sendable, Codable {
    public let width: Int
    public let height: Int
    public internal(set) var cells: [Cell]

    public init(width: Int, height: Int, mines: Set<Coord> = []) {
        self.width = max(1, width)
        self.height = max(1, height)
        self.cells = Array(repeating: Cell(), count: width * height)
        for coord in mines where contains(coord) {
            cells[index(of: coord)].isMine = true
        }
        computeAdjacency()
    }

    public var mineCount: Int { cells.count(where: \.isMine) }

    /// Whether the cell array matches the dimensions. Always true for boards built here; worth
    /// checking on boards decoded from storage before indexing into them.
    public var isWellFormed: Bool {
        width > 0 && height > 0 && cells.count == width * height
    }

    public func contains(_ coord: Coord) -> Bool {
        (0..<width).contains(coord.x) && (0..<height).contains(coord.y)
    }

    public internal(set) subscript(_ coord: Coord) -> Cell {
        get { cells[index(of: coord)] }
        set { cells[index(of: coord)] = newValue }
    }

    public func index(of coord: Coord) -> Int { coord.y * width + coord.x }

    public func coord(at index: Int) -> Coord { Coord(x: index % width, y: index / width) }

    /// Every coordinate in row-major order (matches `cells`).
    public var coordinates: [Coord] { cells.indices.map(coord(at:)) }

    /// The up-to-eight in-bounds cells touching `coord`.
    public func neighbors(of coord: Coord) -> [Coord] {
        var result: [Coord] = []
        result.reserveCapacity(8)
        for dy in -1...1 {
            for dx in -1...1 where dx != 0 || dy != 0 {
                let neighbor = Coord(x: coord.x + dx, y: coord.y + dy)
                if contains(neighbor) { result.append(neighbor) }
            }
        }
        return result
    }

    private mutating func computeAdjacency() {
        for i in cells.indices {
            cells[i].adjacentMines = neighbors(of: coord(at: i)).count { self[$0].isMine }
        }
    }
}
