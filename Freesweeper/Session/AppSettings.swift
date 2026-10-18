import SwiftUI
import SweeperKit

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: Self { self }

    var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// The No Guessing switch: off, or how much logic a board may ask for.
enum NoGuessing: String, CaseIterable, Identifiable {
    case off, easy, medium, hard

    var id: Self { self }

    var logic: NoGuessLogic? {
        switch self {
        case .off: nil
        case .easy: .easy
        case .medium: .medium
        case .hard: .hard
        }
    }

    var displayName: String { logic?.displayName ?? "Off" }

    /// What the choice means, for the info popover in Settings.
    var summary: String {
        switch self {
        case .off: "Ordinary random boards. Sometimes you'll have to guess."
        case .easy: "Every board can be cleared with single numbers and simple patterns like 1-2-1. You never need the mine count."
        case .medium: "Easy, plus the mine counter: sometimes the mines left settle the last few cells."
        case .hard: "Every board can be cleared by logic, but it may take longer chains of reasoning or the mine count near the end."
        }
    }
}

/// A custom board she's played or saved, for Settings › Game's recents and favourites.
struct CustomBoard: Codable, Hashable, Identifiable {
    let width: Int
    let height: Int
    let mines: Int
    /// When it was last played (recents) or favourited (favourites).
    var added: Date

    init(_ difficulty: Difficulty, added: Date = .now) {
        width = difficulty.width
        height = difficulty.height
        mines = difficulty.mines
        self.added = added
    }

    var id: String { "\(width)x\(height)x\(mines)" }
    var difficulty: Difficulty { .custom(width: width, height: height, mines: mines) }

    func matches(_ difficulty: Difficulty) -> Bool {
        width == difficulty.width && height == difficulty.height && mines == difficulty.mines
    }
}

/// User preferences, persisted to UserDefaults on every change. Values read back are
/// validated, so a corrupted or out-of-range entry falls back to something playable.
@MainActor @Observable
final class AppSettings {
    static let longPressRange = 0.2...0.8

    var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) }
    }
    var themeStyle: ThemeStyle {
        didSet { defaults.set(themeStyle.rawValue, forKey: Key.themeStyle) }
    }
    /// Boards are built so they can be cleared by logic alone.
    var noGuessing: NoGuessing {
        didSet { defaults.set(noGuessing.rawValue, forKey: Key.noGuessing) }
    }
    /// Hides the mine counter from the header.
    var showMinesRemaining: Bool {
        didSet { defaults.set(showMinesRemaining, forKey: Key.showMinesRemaining) }
    }
    /// Hides the timer from the header (the game still keeps time).
    var showTimer: Bool {
        didSet { defaults.set(showTimer, forKey: Key.showTimer) }
    }
    /// Adds a lock to the header that ignores board taps, so panning can't dig by accident.
    var showLockButton: Bool {
        didSet { defaults.set(showLockButton, forKey: Key.showLockButton) }
    }
    /// Adds a lightbulb to the header that points at the numbers settling the next move.
    /// Games played with it showing keep separate stats.
    var showHintButton: Bool {
        didSet { defaults.set(showHintButton, forKey: Key.showHintButton) }
    }
    var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Key.haptics) }
    }
    var soundEffects: Bool {
        didSet { defaults.set(soundEffects, forKey: Key.soundEffects) }
    }
    /// The original's once-a-second tick while the timer runs.
    var timerTick: Bool {
        didSet { defaults.set(timerTick, forKey: Key.timerTick) }
    }
    /// Seconds a finger must rest on a cell to flag it.
    var longPressDuration: Double {
        didSet { defaults.set(longPressDuration, forKey: Key.longPress) }
    }
    /// The board size a new game uses.
    var difficulty: Difficulty {
        didSet { defaults.set(try? JSONEncoder().encode(difficulty), forKey: Key.difficulty) }
    }
    /// Custom boards played, newest first.
    private(set) var recentCustomBoards: [CustomBoard] {
        didSet { defaults.set(try? JSONEncoder().encode(recentCustomBoards), forKey: Key.recentCustomBoards) }
    }
    /// Custom boards she's hearted, in the order they were added.
    private(set) var favoriteCustomBoards: [CustomBoard] {
        didSet { defaults.set(try? JSONEncoder().encode(favoriteCustomBoards), forKey: Key.favoriteCustomBoards) }
    }

    /// How many recents and how many favourites are kept.
    static let customBoardLimit = 50

    /// Moves `difficulty` to the front of the recents, dropping the oldest past the limit.
    func noteCustomBoard(_ difficulty: Difficulty) {
        var recents = recentCustomBoards.filter { !$0.matches(difficulty) }
        recents.insert(CustomBoard(difficulty), at: 0)
        recentCustomBoards = Array(recents.prefix(Self.customBoardLimit))
    }

    func removeRecentCustomBoard(_ board: CustomBoard) {
        recentCustomBoards.removeAll { $0.id == board.id }
    }

    func isFavorite(_ difficulty: Difficulty) -> Bool {
        favoriteCustomBoards.contains { $0.matches(difficulty) }
    }

    /// Hearts or un-hearts `difficulty`. Returns `false` if favourites are full and it wasn't added.
    @discardableResult
    func toggleFavorite(_ difficulty: Difficulty) -> Bool {
        if isFavorite(difficulty) {
            favoriteCustomBoards.removeAll { $0.matches(difficulty) }
            return true
        }
        guard favoriteCustomBoards.count < Self.customBoardLimit else { return false }
        favoriteCustomBoards.append(CustomBoard(difficulty))
        return true
    }

    /// Whether `effect` should play. The timer tick also needs the timer on screen; ticking for
    /// a hidden timer would give away what the player chose not to see.
    func allowsSound(_ effect: SoundEffect) -> Bool {
        switch effect {
        case .tick: timerTick && showTimer
        case .reveal, .flag, .explosion, .win: soundEffects
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = defaults.string(forKey: Key.appearance).flatMap(Appearance.init) ?? .system
        themeStyle = defaults.string(forKey: Key.themeStyle).flatMap(ThemeStyle.init) ?? .classic
        // No Guessing used to be on/off, and its boards were what's now Hard.
        noGuessing = defaults.string(forKey: Key.noGuessing).flatMap(NoGuessing.init)
            ?? (defaults.bool(forKey: Key.legacyNoGuessing) ? .hard : .off)
        showMinesRemaining = defaults.object(forKey: Key.showMinesRemaining) as? Bool ?? true
        showTimer = defaults.object(forKey: Key.showTimer) as? Bool ?? true
        showLockButton = defaults.bool(forKey: Key.showLockButton)
        showHintButton = defaults.bool(forKey: Key.showHintButton)
        hapticsEnabled = defaults.object(forKey: Key.haptics) as? Bool ?? true
        soundEffects = defaults.object(forKey: Key.soundEffects) as? Bool ?? true
        timerTick = defaults.bool(forKey: Key.timerTick)
        longPressDuration = (defaults.object(forKey: Key.longPress) as? Double)
            .flatMap { $0.isFinite ? $0.clamped(to: Self.longPressRange) : nil } ?? 0.35
        // Re-clamp so a bad stored size or mine count can't reach the board generator.
        difficulty = defaults.data(forKey: Key.difficulty)
            .flatMap { try? JSONDecoder().decode(Difficulty.self, from: $0) }
            .map { Difficulty.custom(width: $0.width, height: $0.height, mines: $0.mines) }
            ?? Difficulty(shape: .square, size: .small, level: .easy)
        recentCustomBoards = Self.decodeBoards(defaults.data(forKey: Key.recentCustomBoards))
        favoriteCustomBoards = Self.decodeBoards(defaults.data(forKey: Key.favoriteCustomBoards))
        // A custom board chosen before recents existed starts the list.
        if recentCustomBoards.isEmpty, difficulty.isCustom { recentCustomBoards = [CustomBoard(difficulty)] }
    }

    /// Stored boards, re-clamped like `difficulty` and capped, or none if unreadable.
    private static func decodeBoards(_ data: Data?) -> [CustomBoard] {
        let boards = data.flatMap { try? JSONDecoder().decode([CustomBoard].self, from: $0) } ?? []
        return Array(boards.map { CustomBoard($0.difficulty, added: $0.added) }.prefix(customBoardLimit))
    }

    private enum Key {
        static let appearance = "appearance"
        static let themeStyle = "themeStyle"
        static let noGuessing = "noGuessingLogic"
        static let legacyNoGuessing = "noGuessing"
        static let showMinesRemaining = "showMinesRemaining"
        static let showTimer = "showTimer"
        static let showLockButton = "showLockButton"
        static let showHintButton = "showHintButton"
        static let haptics = "haptics"
        static let soundEffects = "soundEffects"
        static let timerTick = "timerTick"
        static let longPress = "longPressDuration"
        static let difficulty = "difficulty"
        static let recentCustomBoards = "recentCustomBoards"
        static let favoriteCustomBoards = "favoriteCustomBoards"
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
