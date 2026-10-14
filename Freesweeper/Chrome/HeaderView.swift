import SwiftUI

/// The current mode in small text, over: mine counter · (lock), flag toggle, smiley, settings · timer.
struct HeaderView: View {
    static let buttonRowHeight: CGFloat = 52

    let onSettings: () -> Void

    @Environment(GameSession.self) private var session
    @Environment(GameFlow.self) private var flow
    @Environment(AppSettings.self) private var settings
    @Environment(\.theme) private var theme

    var body: some View {
        let mines = session.game.minesRemaining
        VStack(spacing: 2) {
            Text(session.statsMode.name)
                .font(.caption2.weight(.medium))
                .foregroundStyle(theme.palette.ink.opacity(0.6))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            // Equal flexible side slots keep the smiley centred whatever the counters' widths,
            // or whether they're shown at all. (ZStack, not Group: an empty Group takes no space.)
            HStack(spacing: 8) {
                ZStack {
                    if settings.showMinesRemaining {
                        CounterView(
                            value: mines,
                            digits: max(3, String(session.game.mineCount).count),
                            systemImage: "flag.fill"
                        )
                            .accessibilityLabel("Mines remaining")
                            .accessibilityValue("\(mines)")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if settings.showLockButton {
                    LockToggle()
                }
                FlagModeToggle()
                SmileyButton(face: session.face) { flow.requestNewGame() }
                SettingsButton(action: onSettings)
                ZStack {
                    if settings.showTimer {
                        TimerCounter()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(height: Self.buttonRowHeight)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }
}

/// Ticks only while a game is running; otherwise frozen on the last value.
private struct TimerCounter: View {
    @Environment(GameSession.self) private var session

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.25, paused: !session.clock.isRunning)) { _ in
            let seconds = session.displaySeconds
            CounterView(value: seconds, digits: 5, systemImage: "clock.fill")
                .accessibilityLabel("Time")
                .accessibilityValue("\(seconds) seconds")
        }
    }
}
