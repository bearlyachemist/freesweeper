/// What a player knows: revealed numbers, cells deduced to be mines, and everything else unknown.
struct Knowledge: Sendable {
    static let unknown: Int8 = -1
    static let mine: Int8 = -2

    /// A revealed cell holds its number (0–8); otherwise `unknown` or `mine`.
    var cells: [Int8]
    let totalMines: Int

    init(cellCount: Int, totalMines: Int) {
        self.cells = Array(repeating: Self.unknown, count: cellCount)
        self.totalMines = totalMines
    }
}

struct Deductions {
    var safe: Set<Int> = []
    var mines: Set<Int> = []

    var isEmpty: Bool { safe.isEmpty && mines.isEmpty }
}

/// How much reasoning a no-guess board may ask of the player.
public enum NoGuessLogic: String, CaseIterable, Codable, Sendable {
    /// Single numbers and overlapping pairs only (1-2-1, 1-1 against a wall, …). No mine counting.
    case easy
    /// Easy plus the mine counter: when one number holds all the mines left, or the rest of the
    /// board is needed to reach the count.
    case medium
    /// Anything that follows from the numbers and the mine count.
    case hard
}

/// A sound minesweeper solver: it only reports cells that are certain from what's visible.
///
/// Reasoning is tried cheapest-first, stopping at the first level that finds anything:
/// 1. **Singles**: a number already satisfied clears its other neighbours; a number with exactly
///    that many unknowns around it makes them all mines.
/// 2. **Pairs**: two overlapping numbers, e.g. if B needs `|B \ A|` more mines than A,
///    then `B \ A` is all mines and `A \ B` all safe (covers 1-2-1, 1-1 against a wall, …).
/// 3. **Regions**: every independent region of the frontier is enumerated exactly by
///    backtracking (state kept in 64-bit masks), then regions are combined with the total
///    mine count to decide cells, including unseen interior cells in the endgame.
///
/// `NoGuessLogic.easy` stops after level 2. `.medium` swaps level 3 for **counting**: what the
/// mines left say on their own, the way a player reads the counter (see `counting`).
enum Solver {
    struct Constraint {
        /// Unknown neighbours, ascending.
        var cells: [Int]
        /// Mines among them.
        var mines: Int
    }

    /// Backtracking steps allowed per call. A region that needs more is treated as undecided,
    /// which can only make the solver more cautious, never wrong.
    static let searchBudget = 1_000_000
    /// Regions are searched with one bit per cell.
    static let maxRegionSize = 64

    /// Certain deductions from `knowledge`. `active` lists the revealed cells worth examining
    /// (those touching an unknown); passing more is fine, just slower.
    static func deduce(
        _ knowledge: Knowledge,
        grid: Grid,
        active: some Sequence<Int>,
        logic: NoGuessLogic = .hard
    ) -> Deductions {
        let constraints = constraints(knowledge, grid: grid, active: active)
        let singles = singles(constraints)
        if !singles.isEmpty { return singles }
        let pairs = pairs(constraints)
        if !pairs.isEmpty { return pairs }
        switch logic {
        case .easy: return pairs
        case .medium: return counting(knowledge, constraints: constraints)
        case .hard: return regions(knowledge, grid: grid, constraints: constraints)
        }
    }

    static func deduce(_ knowledge: Knowledge, grid: Grid, logic: NoGuessLogic = .hard) -> Deductions {
        deduce(knowledge, grid: grid, active: 0..<grid.cellCount, logic: logic)
    }

    // MARK: - Constraints

    static func constraints(_ knowledge: Knowledge, grid: Grid, active: some Sequence<Int>) -> [Constraint] {
        var constraints: [Constraint] = []
        for cell in active {
            let value = knowledge.cells[cell]
            guard value >= 0 else { continue }
            var unknown: [Int] = []
            var knownMines = 0
            for neighbor in grid.neighbors[cell] {
                switch knowledge.cells[neighbor] {
                case Knowledge.unknown: unknown.append(neighbor)
                case Knowledge.mine: knownMines += 1
                default: break
                }
            }
            if !unknown.isEmpty {
                constraints.append(Constraint(cells: unknown, mines: Int(value) - knownMines))
            }
        }
        return constraints
    }

    // MARK: - Level 1 & 2

    static func singles(_ constraints: [Constraint]) -> Deductions {
        var result = Deductions()
        for constraint in constraints {
            if constraint.mines == 0 {
                result.safe.formUnion(constraint.cells)
            } else if constraint.mines == constraint.cells.count {
                result.mines.formUnion(constraint.cells)
            }
        }
        return result
    }

    static func pairs(_ constraints: [Constraint]) -> Deductions {
        var byCell: [Int: [Int]] = [:]
        for (i, constraint) in constraints.enumerated() {
            for cell in constraint.cells { byCell[cell, default: []].append(i) }
        }
        var result = Deductions()
        for (i, a) in constraints.enumerated() {
            var seen: Set<Int> = [i]
            for cell in a.cells {
                for j in byCell[cell, default: []] where seen.insert(j).inserted {
                    let b = constraints[j]
                    let onlyA = a.cells.filter { !b.cells.contains($0) }
                    let onlyB = b.cells.filter { !a.cells.contains($0) }
                    // The shared cells hold at most A's mines, so B's own cells need at least
                    // b − a. If that fills them, A's own cells are left with none. (Seen from
                    // the other side, this also clears B's extra cells when A ⊆ B and a = b.)
                    guard !(onlyA.isEmpty && onlyB.isEmpty), b.mines - a.mines == onlyB.count else { continue }
                    result.mines.formUnion(onlyB)
                    result.safe.formUnion(onlyA)
                }
            }
        }
        return result
    }

    // MARK: - Counting

    /// What the mine counter gives without trying arrangements: every unknown cell together holds
    /// exactly the mines left. That group is checked like a single number (all safe / all mines)
    /// and like a pair with every number, e.g. a corner ringed by 1s that could hold one mine or
    /// two is settled once everything else is clear and the counter says one is left.
    ///
    /// Counting only the whole board, rather than the board minus some chosen numbers, keeps
    /// this order-independent: whatever order a player clears in, it stays available.
    static func counting(_ knowledge: Knowledge, constraints: [Constraint]) -> Deductions {
        let unknown = Set(knowledge.cells.indices.filter { knowledge.cells[$0] == Knowledge.unknown })
        let remaining = knowledge.totalMines - knowledge.cells.count { $0 == Knowledge.mine }
        guard !unknown.isEmpty, (0...unknown.count).contains(remaining) else { return Deductions() }

        var result = Deductions()
        if remaining == 0 { result.safe = unknown }
        if remaining == unknown.count { result.mines = unknown }
        // Every number's unknown cells lie inside `unknown`, so the pair rule from `pairs` reads:
        for constraint in constraints {
            let outside = unknown.count - constraint.cells.count
            if constraint.mines == remaining {
                // This number holds every mine left; nothing else can be one.
                result.safe.formUnion(unknown.subtracting(constraint.cells))
            } else if remaining - constraint.mines == outside {
                // Every cell this number doesn't touch is needed to reach the count.
                result.mines.formUnion(unknown.subtracting(constraint.cells))
            }
        }
        return result
    }

    // MARK: - Level 3

    /// Which cells were a mine / safe in at least one arrangement with a given mine count.
    struct Seen {
        var mine: UInt64 = 0
        var safe: UInt64 = 0
    }

    struct Region {
        /// Cells in search order; bit `i` of a mask is `cells[i]`.
        var cells: [Int]
        /// Arrangements by mine count, or `nil` if the region was too big to search.
        var arrangements: [Int: Seen]?

        var possibleCounts: [Int] {
            arrangements.map { Array($0.keys) } ?? Array(0...cells.count)
        }
    }

    static func regions(_ knowledge: Knowledge, grid: Grid, constraints: [Constraint]) -> Deductions {
        // Number the frontier cells and union constraints that share a cell into regions.
        var frontierID: [Int: Int] = [:]
        var frontier: [Int] = []
        for constraint in constraints {
            for cell in constraint.cells where frontierID[cell] == nil {
                frontierID[cell] = frontier.count
                frontier.append(cell)
            }
        }
        var parent = Array(frontier.indices)
        func root(_ x: Int) -> Int {
            var x = x
            while parent[x] != x {
                parent[x] = parent[parent[x]]
                x = parent[x]
            }
            return x
        }
        for constraint in constraints {
            let first = root(frontierID[constraint.cells[0]]!)
            for cell in constraint.cells.dropFirst() {
                let other = root(frontierID[cell]!)
                if other != first { parent[other] = first }
            }
        }
        var regionConstraints: [Int: [Constraint]] = [:]
        for constraint in constraints {
            regionConstraints[root(frontierID[constraint.cells[0]]!), default: []].append(constraint)
        }

        var budget = searchBudget
        let regions = regionConstraints.values.map { search($0, budget: &budget) }

        // Combine regions with the global mine count.
        let knownMines = knowledge.cells.count { $0 == Knowledge.mine }
        let unknownCount = knowledge.cells.count { $0 == Knowledge.unknown }
        let remaining = knowledge.totalMines - knownMines
        let interior = unknownCount - frontier.count
        guard remaining >= 0 else { return Deductions() }

        // sums[k]: mine totals reachable by regions 0..<k; suffixSums[k]: by regions k...
        func adding(_ reachable: [Bool], _ counts: [Int]) -> [Bool] {
            var next = Array(repeating: false, count: remaining + 1)
            for sum in 0...remaining where reachable[sum] {
                for count in counts where sum + count <= remaining { next[sum + count] = true }
            }
            return next
        }
        var none = Array(repeating: false, count: remaining + 1)
        none[0] = true
        var prefix = [none]
        for region in regions { prefix.append(adding(prefix.last!, region.possibleCounts)) }
        var suffix = Array(repeating: none, count: regions.count + 1)
        for k in regions.indices.reversed() { suffix[k] = adding(suffix[k + 1], regions[k].possibleCounts) }

        /// Whether the regions other than `k` can total something in `low...high`.
        func othersCanTotal(excluding k: Int, _ low: Int, _ high: Int) -> Bool {
            let low = max(low, 0), high = min(high, remaining)
            guard low <= high else { return false }
            // Running count of reachable suffix totals, for O(1) range checks.
            var counts = [0]
            for reachable in suffix[k + 1] { counts.append(counts.last! + (reachable ? 1 : 0)) }
            for before in 0...remaining where prefix[k][before] {
                let from = max(low - before, 0), to = min(high - before, remaining)
                if from <= to, counts[to + 1] - counts[from] > 0 { return true }
            }
            return false
        }

        var result = Deductions()
        for (k, region) in regions.enumerated() {
            guard let arrangements = region.arrangements else { continue }
            // A count is feasible if the rest of the board can absorb the remaining mines.
            let feasible = arrangements.keys.filter { count in
                othersCanTotal(excluding: k, remaining - count - interior, remaining - count)
            }
            guard !feasible.isEmpty else { continue }
            var canBeMine: UInt64 = 0, canBeSafe: UInt64 = 0
            for count in feasible {
                canBeMine |= arrangements[count]!.mine
                canBeSafe |= arrangements[count]!.safe
            }
            for (bit, cell) in region.cells.enumerated() {
                let mask = UInt64(1) << UInt64(bit)
                if canBeSafe & mask == 0 { result.mines.insert(cell) }
                if canBeMine & mask == 0 { result.safe.insert(cell) }
            }
        }

        // Unseen interior cells are decided only when the count leaves them no choice.
        if interior > 0 {
            let interiorCounts = (0...remaining)
                .filter { prefix[regions.count][$0] }
                .map { remaining - $0 }
                .filter { (0...interior).contains($0) }
            if let most = interiorCounts.max(), let least = interiorCounts.min(), most == 0 || least == interior {
                let interiorCells = knowledge.cells.indices.filter {
                    knowledge.cells[$0] == Knowledge.unknown && frontierID[$0] == nil
                }
                if most == 0 { result.safe.formUnion(interiorCells) } else { result.mines.formUnion(interiorCells) }
            }
        }
        return result
    }

    /// Enumerates every arrangement of mines in one region that satisfies its constraints.
    static func search(_ constraints: [Constraint], budget: inout Int) -> Region {
        // Visit cells breadth-first through shared constraints so each constraint fills up
        // (and prunes) as early as possible.
        var constraintsOfCell: [Int: [Int]] = [:]
        for (i, constraint) in constraints.enumerated() {
            for cell in constraint.cells { constraintsOfCell[cell, default: []].append(i) }
        }
        var order: [Int] = []
        var queued: Set<Int> = []
        for start in constraints.flatMap(\.cells) where queued.insert(start).inserted {
            var queue = [start]
            var head = 0
            while head < queue.count {
                let cell = queue[head]
                head += 1
                order.append(cell)
                for i in constraintsOfCell[cell]! {
                    for other in constraints[i].cells where queued.insert(other).inserted {
                        queue.append(other)
                    }
                }
            }
        }
        guard order.count <= maxRegionSize else { return Region(cells: order, arrangements: nil) }

        let n = order.count
        let constraintsAt = order.map { constraintsOfCell[$0]! }
        let target = constraints.map(\.mines)
        var unassigned = constraints.map(\.cells.count)
        var assigned = Array(repeating: 0, count: constraints.count)
        let all: UInt64 = n == 64 ? .max : (UInt64(1) << UInt64(n)) - 1
        var arrangements: [Int: Seen] = [:]
        var aborted = false

        func place(_ position: Int, _ mask: UInt64, _ count: Int) {
            guard !aborted else { return }
            budget -= 1
            if budget < 0 {
                aborted = true
                return
            }
            if position == n {
                arrangements[count, default: Seen()].mine |= mask
                arrangements[count, default: Seen()].safe |= ~mask & all
                return
            }
            for value in 0...1 {
                var consistent = true
                for i in constraintsAt[position] {
                    unassigned[i] -= 1
                    assigned[i] += value
                    if assigned[i] > target[i] || assigned[i] + unassigned[i] < target[i] { consistent = false }
                }
                if consistent {
                    place(position + 1, value == 1 ? mask | (UInt64(1) << UInt64(position)) : mask, count + value)
                }
                for i in constraintsAt[position] {
                    unassigned[i] += 1
                    assigned[i] -= value
                }
            }
        }
        place(0, 0, 0)
        return Region(cells: order, arrangements: aborted ? nil : arrangements)
    }
}
