import SwiftUI

/// Shows a hint: the numbers that settle the next move light up until she makes a move.
/// Tapping again hides it. Drawn pushed-in while a hint is showing.
struct HintToggle: View {
    @Environment(GameSession.self) private var session
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let isOn = session.hint != nil
        let palette = theme.palette
        let iconColor = switch theme.chrome {
        case .classic: isOn ? Color.hint : palette.ink.opacity(0.55)
        case .modern: isOn ? palette.onAccent : palette.ink.opacity(0.7)
        }
        Button {
            session.toggleHint()
        } label: {
            Image(systemName: isOn ? "lightbulb.fill" : "lightbulb")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(iconColor)
                .frame(width: 26, height: 26)
                .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
        }
        .buttonStyle(HeaderButtonStyle(isSelected: isOn))
        .disabled(session.game.status != .playing)
        .accessibilityLabel("Hint")
        .accessibilityValue(isOn ? "Showing" : "")
        .accessibilityHint("Highlights the numbers that settle your next move")
    }
}

extension Color {
    /// Hint highlights: a warm amber that reads on both themes' boards.
    static let hint = Color(red: 1, green: 0.7, blue: 0)
}

/// Pulses a hint-coloured outline around a view while `isActive`, e.g. the mine counter when
/// a hint needs the mine count.
struct HintPulse: ViewModifier {
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay {
            if isActive {
                let outline = RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.hint, lineWidth: 3)
                    .padding(-3)
                if reduceMotion {
                    outline
                } else {
                    outline.phaseAnimator([1, 0.25]) { view, opacity in
                        view.opacity(opacity)
                    } animation: { _ in .easeInOut(duration: 0.6) }
                }
            }
        }
    }
}

extension EnvironmentValues {
    /// The header is short on width (e.g. lock and hint both on, on a small phone): counters
    /// and buttons draw a little smaller.
    @Entry var compactHeader = false
}
