public enum GameStatus: Hashable, Sendable, Codable {
    /// No cell dug yet; mines aren't placed and the timer hasn't started.
    case ready
    case playing
    case won
    case lost(exploded: Coord)

    public var isOver: Bool {
        switch self {
        case .won, .lost: true
        case .ready, .playing: false
        }
    }
}
