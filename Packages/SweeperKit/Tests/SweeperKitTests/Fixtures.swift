@testable import SweeperKit

/// The original Windows boards (expert stood upright for a portrait phone), as test fixtures.
extension Difficulty {
    static let beginner = Difficulty(width: 9, height: 9, mines: 10)
    static let intermediate = Difficulty(width: 16, height: 16, mines: 40)
    static let expert = Difficulty(width: 16, height: 30, mines: 99)
}
