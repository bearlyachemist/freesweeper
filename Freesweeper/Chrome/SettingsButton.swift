import SwiftUI

/// Gear in the header that opens Settings, styled to match the smiley and flag buttons.
struct SettingsButton: View {
    let action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(theme.palette.ink.opacity(0.7))
                .frame(width: 26, height: 26)
        }
        .buttonStyle(HeaderButtonStyle())
        .accessibilityLabel("Settings")
    }
}
