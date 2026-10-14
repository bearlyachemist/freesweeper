/// Neighbour lists by flat cell index (`y * width + x`), shared by the solver and generator.
/// Lists are in ascending index order.
struct Grid: Sendable {
    let width: Int
    let height: Int
    let neighbors: [[Int]]

    var cellCount: Int { width * height }

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        var neighbors: [[Int]] = []
        neighbors.reserveCapacity(width * height)
        for y in 0..<height {
            for x in 0..<width {
                var list: [Int] = []
                list.reserveCapacity(8)
                for dy in -1...1 {
                    for dx in -1...1 where dx != 0 || dy != 0 {
                        let nx = x + dx, ny = y + dy
                        if (0..<width).contains(nx), (0..<height).contains(ny) {
                            list.append(ny * width + nx)
                        }
                    }
                }
                neighbors.append(list)
            }
        }
        self.neighbors = neighbors
    }
}
