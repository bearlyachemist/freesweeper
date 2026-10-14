import SwiftUI

@main
struct FreesweeperApp: App {
    @State private var settings: AppSettings
    @State private var session: GameSession
    @State private var stats: StatsStore
    @State private var flow: GameFlow

    init() {
        let settings = AppSettings()
        let stats = StatsStore()
        _settings = State(initialValue: settings)
        _stats = State(initialValue: stats)
        let session = GameSession(settings: settings, sounds: SoundEffects(), stats: stats)
        _session = State(initialValue: session)
        _flow = State(initialValue: GameFlow(session: session, settings: settings, stats: stats))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(session)
                .environment(stats)
                .environment(flow)
                .preferredColorScheme(settings.appearance.colorScheme)
        }
    }
}

/// Resolves the theme from the chosen style and the effective color scheme.
private struct RootView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = Theme.resolve(settings.themeStyle, colorScheme: colorScheme)
        GameScreen()
            .environment(\.theme, theme)
            .tint(theme.palette.accent)
    }
}
