import SweeperKit

extension Difficulty {
    var summary: String { "\(width) × \(height) · \(mines) \(mines == 1 ? "mine" : "mines")" }

    /// Short name of the current mode for the header, e.g. "X-Large Rectangle · Hard".
    var modeName: String {
        guard let shape, let size else { return "Custom \(summary)" }
        let board = "\(size.displayName) \(shape.displayName)"
        return "\(board) · \(level?.displayName ?? "\(mines) \(mines == 1 ? "mine" : "mines")")"
    }
}

extension Difficulty.Shape {
    var displayName: String {
        switch self {
        case .square: "Square"
        case .rectangle: "Rectangle"
        }
    }
}

extension Difficulty.Size {
    var displayName: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        case .extraLarge: "X-Large"
        case .massive: "Massive"
        }
    }
}

extension NoGuessLogic {
    var displayName: String {
        switch self {
        case .easy: "Easy"
        case .medium: "Medium"
        case .hard: "Hard"
        }
    }
}

extension Difficulty.Level {
    var displayName: String {
        switch self {
        case .easy: "Easy"
        case .medium: "Medium"
        case .hard: "Hard"
        }
    }
}
