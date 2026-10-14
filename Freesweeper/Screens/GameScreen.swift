import SwiftUI

struct GameScreen: View {
    @Environment(GameSession.self) private var session
    @Environment(GameFlow.self) private var flow
    @Environment(AppSettings.self) private var settings
    @Environment(\.theme) private var theme
    @Environment(\.scenePhase) private var scenePhase

    @State private var isShowingSettings = false

    var body: some View {
        VStack(spacing: 0) {
            HeaderView { isShowingSettings = true }
            GeometryReader { proxy in
                let board = session.game.board
                BoardView(layout: BoardLayout(columns: board.width, rows: board.height, available: proxy.size))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .background(theme.palette.background.ignoresSafeArea())
        .overlay { resultOverlay }
        .animation(.easeOut(duration: 0.25), value: flow.presentedResult?.id)
        // While Settings is up it shows the confirmation itself.
        .confirmsNewGame(isEnabled: !isShowingSettings)
        .sheet(isPresented: $isShowingSettings) { SettingsScreen() }
        .onChange(of: scenePhase, initial: true) { session.scenePhaseChanged($1) }
        .alert("No Guessing Unavailable", isPresented: noGuessUnavailable) {
            Button("Reset") { flow.requestNewGame() }
            Button("OK", role: .cancel) {}
        } message: {
            Text("No Guessing was unavailable for this board. Please reset and try again.")
        }
        .sensoryFeedback(trigger: session.flagChanges) { _, _ in
            settings.hapticsEnabled ? .impact(weight: .medium) : nil
        }
        .sensoryFeedback(trigger: session.game.status) { _, status in
            guard settings.hapticsEnabled else { return nil }
            return switch status {
            case .won: .success
            case .lost: .error
            case .ready, .playing: nil
            }
        }
    }

    private var noGuessUnavailable: Binding<Bool> {
        Binding(get: { flow.noGuessUnavailable }, set: { flow.noGuessUnavailable = $0 })
    }

    @ViewBuilder
    private var resultOverlay: some View {
        if let result = flow.presentedResult {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { flow.dismissResult() }
                if result.won {
                    ConfettiView(colors: theme.palette.numbers.prefix(6) + [theme.palette.smiley])
                        .ignoresSafeArea()
                }
                ResultCard(
                    result: result,
                    onPlayAgain: { flow.requestNewGame() },
                    onViewBoard: { flow.dismissResult() }
                )
            }
            .transition(.opacity)
        }
    }
}
