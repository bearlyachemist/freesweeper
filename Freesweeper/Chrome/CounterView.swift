import SwiftUI

/// A header counter in the current theme's style: classic red LED digits, or a modern pill
/// with an icon and plain numbers.
struct CounterView: View {
    let value: Int
    let digits: Int
    let systemImage: String

    @Environment(\.theme) private var theme
    @Environment(\.compactHeader) private var compact

    var body: some View {
        switch theme.chrome {
        case .classic(let colors):
            LEDCounter(value: value, digits: digits, colors: colors)
        case .modern:
            HStack(spacing: 5) {
                if !compact {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.palette.ink.opacity(0.55))
                }
                Text("\(value)")
                    .font(.system(size: compact ? 17 : 20, weight: .semibold, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText())
                    .foregroundStyle(theme.palette.ink)
            }
            .padding(.horizontal, compact ? 8 : 12)
            .frame(height: 36)
            .background(theme.palette.buttonFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}
