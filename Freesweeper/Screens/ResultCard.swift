import SwiftUI

/// The pop-up after a game: a cheerful headline, the time (and whether it's a new best), and
/// both streaks animating from their old values to their new ones.
struct ResultCard: View {
    let result: GameResult
    let onPlayAgain: () -> Void
    let onViewBoard: () -> Void

    @Environment(\.theme) private var theme
    @State private var modeStreak: Int
    @State private var overallStreak: Int
    @State private var appeared = false

    private static let winTitles = ["You did it!", "Nicely swept!", "Flawless!", "Mine-free!", "Brilliant!"]
    private static let lossTitles = ["Kaboom!", "So close!", "Oops, a mine!", "Shake it off!", "Boom goes the board!"]
    private static let gold = Color(hex: 0xF5B301)
    /// Streak tiles and buttons share one size so the card reads as a 2×2 grid.
    fileprivate static let tileHeight: CGFloat = 64

    init(result: GameResult, onPlayAgain: @escaping () -> Void, onViewBoard: @escaping () -> Void) {
        self.result = result
        self.onPlayAgain = onPlayAgain
        self.onViewBoard = onViewBoard
        _modeStreak = State(initialValue: result.modeStreakBefore)
        _overallStreak = State(initialValue: result.overallStreakBefore)
    }

    var body: some View {
        let palette = theme.palette
        let titles = result.won ? Self.winTitles : Self.lossTitles

        VStack(spacing: 16) {
            Image(systemName: result.won ? "trophy.fill" : "burst.fill")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(result.won ? Self.gold : palette.flag)
                .symbolEffect(.bounce, value: appeared)

            VStack(spacing: 4) {
                Text(titles[result.flavor % titles.count])
                    .font(.system(.title, design: .rounded, weight: .bold))
                Text(result.modeName)
                    .font(.footnote)
                    .foregroundStyle(palette.ink.opacity(0.6))
            }

            if result.won { time }

            HStack(spacing: 10) {
                streakTile("This Mode", value: modeStreak)
                streakTile("Overall", value: overallStreak)
            }

            if !result.won, result.overallStreakBefore > 1 {
                Text("Your \(result.overallStreakBefore)-game streak ended. Go again!")
                    .font(.footnote)
                    .foregroundStyle(palette.ink.opacity(0.7))
            }

            HStack(spacing: 10) {
                Button("View Board", action: onViewBoard)
                    .buttonStyle(TileButtonStyle(isProminent: false))
                Button("Play Again", action: onPlayAgain)
                    .buttonStyle(TileButtonStyle(isProminent: true))
            }
        }
        .foregroundStyle(palette.ink)
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(maxWidth: 330)
        .modifier(CardChrome())
        .padding(24)
        .scaleEffect(appeared ? 1 : 0.85)
        .opacity(appeared ? 1 : 0)
        .task {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { appeared = true }
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                modeStreak = result.modeStreakAfter
                overallStreak = result.overallStreakAfter
            }
        }
    }

    private var time: some View {
        VStack(spacing: 6) {
            Text(formatGameTime(result.time))
                .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
            if let previous = result.previousBest {
                if result.isNewBest {
                    badge("New best time!", systemImage: "star.fill")
                    Text("Previous best \(formatGameTime(previous))")
                        .font(.caption)
                        .foregroundStyle(theme.palette.ink.opacity(0.6))
                } else {
                    Text("Best \(formatGameTime(previous))")
                        .font(.caption)
                        .foregroundStyle(theme.palette.ink.opacity(0.6))
                }
            } else {
                badge("First win on this board!", systemImage: "sparkles")
            }
        }
    }

    private func badge(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Self.gold, in: Capsule())
            .symbolEffect(.bounce, value: appeared)
    }

    private func streakTile(_ label: String, value: Int) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(value > 0 ? .orange : theme.palette.ink.opacity(0.3))
                Text("\(value)")
                    .font(.system(.title2, design: .rounded, weight: .bold).monospacedDigit())
                    .contentTransition(.numericText(value: Double(value)))
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(theme.palette.ink.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.tileHeight)
        .background(theme.palette.ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) streak, \(value)")
    }
}

/// A button the same size and shape as a streak tile.
private struct TileButtonStyle: ButtonStyle {
    let isProminent: Bool

    @Environment(\.theme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        let palette = theme.palette
        configuration.label
            .font(.headline)
            .foregroundStyle(isProminent ? palette.onAccent : palette.accent)
            .frame(maxWidth: .infinity)
            .frame(height: ResultCard.tileHeight)
            .background(
                isProminent ? palette.accent : palette.accent.opacity(0.12),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

/// Classic: a raised gray window. Modern: a rounded card with a soft shadow.
private struct CardChrome: ViewModifier {
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        switch theme.chrome {
        case .classic(let colors):
            content
                .background(theme.palette.face)
                .bevel(.raised, width: 3, colors: colors)
        case .modern:
            content
                .background(theme.palette.revealed, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 24, y: 8)
        }
    }
}

/// A short burst of falling paper for wins.
struct ConfettiView: View {
    let colors: [Color]

    private struct Piece {
        var x = Double.random(in: 0...1)
        var delay = Double.random(in: 0...0.5)
        var fall = Double.random(in: 0.35...0.6)
        var sway = Double.random(in: 10...30)
        var phase = Double.random(in: 0...(2 * .pi))
        var spin = Double.random(in: -6...6)
        var size = CGSize(width: .random(in: 6...10), height: .random(in: 8...14))
        var color = Int.random(in: 0..<100)
    }

    @State private var start = Date.now
    @State private var pieces = (0..<80).map { _ in Piece() }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(start)
                for piece in pieces {
                    let local = t - piece.delay
                    guard local > 0 else { continue }
                    let y = -20 + local * piece.fall * size.height
                    guard y < size.height + 20 else { continue }
                    let x = piece.x * size.width + sin(local * 3 + piece.phase) * piece.sway
                    var context = context
                    context.translateBy(x: x, y: y)
                    context.rotate(by: .radians(local * piece.spin))
                    let rect = CGRect(x: -piece.size.width / 2, y: -piece.size.height / 4,
                                      width: piece.size.width, height: piece.size.height / 2)
                    context.fill(Path(rect), with: .color(colors[piece.color % colors.count]))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
