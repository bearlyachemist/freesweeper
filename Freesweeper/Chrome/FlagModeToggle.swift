import SwiftUI

/// Switches what a tap does. Off: tap digs, long press flags. On: tap flags, long press digs.
/// Drawn pushed-in while flag mode is on, and the flag gives a little wave on every tap.
struct FlagModeToggle: View {
    @Environment(GameSession.self) private var session
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Bumped on each tap to replay the wave.
    @State private var waves = 0

    var body: some View {
        let isOn = session.inputMode == .flag
        let palette = theme.palette
        // Classic shows a red flag in a pushed-in button; modern a white flag on the accent.
        let iconColor = switch theme.chrome {
        case .classic: isOn ? palette.flag : palette.ink.opacity(0.55)
        case .modern: isOn ? palette.onAccent : palette.ink.opacity(0.7)
        }
        Button {
            session.inputMode = isOn ? .reveal : .flag
            if !reduceMotion { waves += 1 }
        } label: {
            Image(systemName: "flag.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(iconColor)
                .modifier(WavingFlag(trigger: waves))
                .frame(width: 26, height: 26)
        }
        .buttonStyle(HeaderButtonStyle(isSelected: isOn))
        .accessibilityLabel("Flag mode")
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityHint("When on, tapping a cell flags it")
    }
}

private struct Wave {
    var angle = 0.0
    var stretch = 1.0
}

/// Swings the flag around the foot of its pole, like a flag catching the wind, then settles.
private struct WavingFlag: ViewModifier {
    let trigger: Int

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: Wave(), trigger: trigger) { flag, wave in
            flag
                .scaleEffect(x: wave.stretch, y: 1, anchor: .leading)
                .rotationEffect(.degrees(wave.angle), anchor: .bottomLeading)
        } keyframes: { _ in
            KeyframeTrack(\.angle) {
                CubicKeyframe(-14, duration: 0.1)
                CubicKeyframe(10, duration: 0.14)
                CubicKeyframe(-6, duration: 0.12)
                CubicKeyframe(3, duration: 0.1)
                SpringKeyframe(0, duration: 0.18)
            }
            KeyframeTrack(\.stretch) {
                CubicKeyframe(0.86, duration: 0.1)
                CubicKeyframe(1.06, duration: 0.14)
                CubicKeyframe(0.95, duration: 0.12)
                SpringKeyframe(1, duration: 0.28)
            }
        }
    }
}
