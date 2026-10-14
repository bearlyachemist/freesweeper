import SwiftUI
import SweeperKit

struct SettingsScreen: View {
    @Environment(AppSettings.self) private var settings
    @Environment(GameFlow.self) private var flow
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                gameSection
                StatsSection(mode: StatsMode(difficulty: settings.difficulty, noGuessing: settings.noGuessing))

                Section("Look") {
                    Picker("Style", selection: $settings.themeStyle) {
                        ForEach(ThemeStyle.allCases) { Text($0.displayName).tag($0) }
                    }
                    Picker("Appearance", selection: $settings.appearance) {
                        ForEach(Appearance.allCases) { Text($0.displayName).tag($0) }
                    }
                }

                Section {
                    Toggle("Show Mines Remaining", isOn: $settings.showMinesRemaining)
                    Toggle("Show Timer", isOn: $settings.showTimer)
                    Toggle("Show Lock Button", isOn: $settings.showLockButton)
                    Toggle("Haptics", isOn: $settings.hapticsEnabled)
                    VStack(alignment: .leading) {
                        Text("Long Press: \(settings.longPressDuration, format: .number.precision(.fractionLength(2))) s")
                        Slider(value: $settings.longPressDuration, in: AppSettings.longPressRange, step: 0.05) {
                            Text("Long Press")
                        } minimumValueLabel: {
                            Text("Fast")
                        } maximumValueLabel: {
                            Text("Slow")
                        }
                    }
                } header: {
                    Text("Gameplay")
                } footer: {
                    Text("The lock button stops taps on the board so you can scroll big boards safely. Long press is how long to hold a cell to flag it (or to dig it in flag mode).")
                }

                Section {
                    Toggle("Sound Effects", isOn: $settings.soundEffects)
                    Toggle("Timer Tick", isOn: $settings.timerTick)
                } header: {
                    Text("Sound")
                } footer: {
                    Text("Sounds follow the ring/silent switch.")
                }
            }
            .confirmsNewGame()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var gameSection: some View {
        @Bindable var settings = settings
        let current = settings.difficulty
        return Section {
            optionRow("Shape", selection: Binding(
                get: { current.shape },
                set: { if let shape = $0 { flow.requestNewGame(current.with(shape: shape)) } }
            )) {
                ForEach(Difficulty.Shape.allCases, id: \.self) { Text($0.displayName).tag(Optional($0)) }
            }
            optionRow("Size", selection: Binding(
                get: { current.size },
                set: { if let size = $0 { flow.requestNewGame(current.with(size: size)) } }
            )) {
                ForEach(Difficulty.Size.allCases, id: \.self) { Text($0.displayName).tag(Optional($0)) }
            }
            optionRow("Difficulty", selection: Binding(
                get: { current.level },
                set: { if let level = $0 { flow.requestNewGame(current.with(level: level)) } }
            )) {
                ForEach(Difficulty.Level.allCases, id: \.self) { Text($0.displayName).tag(Optional($0)) }
            }
            Toggle("No Guessing", isOn: $settings.noGuessing)
            NavigationLink("Custom…") {
                CustomDifficultyScreen { dismiss() }
            }
        } header: {
            Text("Game")
        } footer: {
            Text("\(current.summary). Changing starts a new game.")
        }
    }

    /// A caption over a segmented control. A custom board selects nothing.
    private func optionRow<Value: Hashable, Options: View>(
        _ title: String,
        selection: Binding<Value?>,
        @ViewBuilder options: () -> Options
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Picker(title, selection: selection, content: options)
                .pickerStyle(.segmented)
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}
