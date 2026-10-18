import SwiftUI
import SweeperKit

/// Recent or favourite custom boards. Tapping one starts it and calls `onStart` so Settings
/// can close; swiping removes it from the list.
struct CustomBoardsScreen: View {
    enum Kind {
        case recent, favorites

        var title: String {
            switch self {
            case .recent: "Recent"
            case .favorites: "Favourites"
            }
        }
    }

    let kind: Kind
    let onStart: () -> Void

    @Environment(GameFlow.self) private var flow
    @Environment(AppSettings.self) private var settings
    @AppStorage("favoriteSort") private var sort = FavoriteSort.dateAdded

    var body: some View {
        let boards = boards
        List {
            ForEach(boards) { board in
                Button {
                    if flow.requestNewGame(board.difficulty) { onStart() }
                } label: {
                    CustomBoardLabel(board: board, isCurrent: board.matches(settings.difficulty))
                }
                .tint(.primary)
                .swipeActions {
                    Button("Remove", role: .destructive) { remove(board) }
                }
            }
        }
        .overlay {
            if boards.isEmpty {
                ContentUnavailableView(
                    kind == .recent ? "No Recent Boards" : "No Favourites",
                    systemImage: kind == .recent ? "clock" : "heart",
                    description: Text(kind == .recent
                        ? "Custom boards you play show up here."
                        : "Tap the heart on a custom board to keep it here.")
                )
            }
        }
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if kind == .favorites {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Picker("Sort By", selection: $sort) {
                            ForEach(FavoriteSort.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }
                }
            }
        }
    }

    private var boards: [CustomBoard] {
        switch kind {
        case .recent: settings.recentCustomBoards
        case .favorites: sort.sorted(settings.favoriteCustomBoards)
        }
    }

    private func remove(_ board: CustomBoard) {
        switch kind {
        case .recent: settings.removeRecentCustomBoard(board)
        case .favorites: settings.toggleFavorite(board.difficulty)
        }
    }
}

enum FavoriteSort: String, CaseIterable {
    case dateAdded, size, mines

    var displayName: String {
        switch self {
        case .dateAdded: "Date Added"
        case .size: "Size"
        case .mines: "Mines"
        }
    }

    /// Newest first by date; smallest first by size (area) or mine count, the other breaking ties.
    func sorted(_ boards: [CustomBoard]) -> [CustomBoard] {
        switch self {
        case .dateAdded: boards.sorted { $0.added > $1.added }
        case .size: boards.sorted { ($0.width * $0.height, $0.mines) < ($1.width * $1.height, $1.mines) }
        case .mines: boards.sorted { ($0.mines, $0.width * $0.height) < ($1.mines, $1.width * $1.height) }
        }
    }
}

/// "30 × 30" over "150 mines · 17%", a checkmark if it's the board being played, and a heart.
struct CustomBoardLabel: View {
    let board: CustomBoard
    let isCurrent: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(board.width) × \(board.height)")
                Text("\(board.mines) \(board.mines == 1 ? "mine" : "mines") · \(board.difficulty.density, format: .percent.precision(.fractionLength(0)))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isCurrent {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
                    .accessibilityLabel("Current board")
            }
            FavoriteButton(difficulty: board.difficulty)
        }
    }
}

/// A heart that saves a custom board to favourites, or takes it off.
struct FavoriteButton: View {
    let difficulty: Difficulty

    @Environment(AppSettings.self) private var settings
    @State private var isShowingFull = false

    var body: some View {
        let isFavorite = settings.isFavorite(difficulty)
        Button {
            if !settings.toggleFavorite(difficulty) { isShowingFull = true }
        } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .foregroundStyle(isFavorite ? Color.red : Color.secondary)
                .contentTransition(.symbolEffect(.replace))
        }
        // Borderless, so only the heart toggles and the rest of the row still starts the board.
        .buttonStyle(.borderless)
        .accessibilityLabel(isFavorite ? "Remove from Favourites" : "Add to Favourites")
        .alert("Favourites Full", isPresented: $isShowingFull) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You can keep up to \(AppSettings.customBoardLimit) favourites. Remove one to add another.")
        }
    }
}
