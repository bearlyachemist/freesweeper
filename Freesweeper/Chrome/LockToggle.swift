import SwiftUI

/// Locks the board against taps and long presses so scrolling a big board can't dig or flag
/// by accident. Panning and zooming still work. Drawn pushed-in while locked.
struct LockToggle: View {
    @Environment(GameSession.self) private var session
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let isOn = session.isLocked
        let palette = theme.palette
        let iconColor = switch theme.chrome {
        case .classic: palette.ink.opacity(isOn ? 1 : 0.55)
        case .modern: isOn ? palette.onAccent : palette.ink.opacity(0.7)
        }
        Button {
            session.isLocked.toggle()
        } label: {
            Image(systemName: isOn ? "lock.fill" : "lock.open.fill")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(iconColor)
                .frame(width: 26, height: 26)
                .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
        }
        .buttonStyle(HeaderButtonStyle(isSelected: isOn))
        .accessibilityLabel("Lock board")
        .accessibilityValue(isOn ? "Locked" : "Unlocked")
        .accessibilityHint("When locked, tapping the board does nothing, so you can scroll safely")
    }
}
