import SwiftUI

/// The header's square buttons, in the current theme's style. Classic: a gray bevel that
/// looks pushed in while pressed or selected. Modern: a rounded tile, accent-filled when selected.
struct HeaderButtonStyle: ButtonStyle {
    var isSelected = false

    func makeBody(configuration: Configuration) -> some View {
        ThemedButtonBody(configuration: configuration, isSelected: isSelected)
    }

    private struct ThemedButtonBody: View {
        @Environment(\.theme) private var theme
        let configuration: Configuration
        let isSelected: Bool

        var body: some View {
            let palette = theme.palette
            switch theme.chrome {
            case .classic(let colors):
                let isSunken = configuration.isPressed || isSelected
                configuration.label
                    .foregroundStyle(palette.ink)
                    .padding(5)
                    .offset(x: isSunken ? 1 : 0, y: isSunken ? 1 : 0)
                    .background(palette.face)
                    .bevel(isSunken ? .sunken : .raised, width: 3, colors: colors)
            case .modern:
                configuration.label
                    .foregroundStyle(palette.ink)
                    .frame(width: 44, height: 44)
                    .background(
                        isSelected ? palette.accent : palette.buttonFill,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .scaleEffect(configuration.isPressed ? 0.92 : 1)
                    .animation(.snappy(duration: 0.15), value: configuration.isPressed)
            }
        }
    }
}
