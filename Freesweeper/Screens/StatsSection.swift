import SwiftUI

/// Stats for the mode currently selected in Settings › Game, plus the overall streak.
struct StatsSection: View {
    let mode: StatsMode

    @Environment(StatsStore.self) private var stats
    @State private var isConfirmingReset = false

    var body: some View {
        let mode = stats.stats(for: mode)
        Section {
            LabeledContent("Played", value: "\(mode.played)")
            LabeledContent("Won") {
                if let rate = mode.winRate {
                    Text("\(mode.won) (\(rate, format: .percent.precision(.fractionLength(0))))")
                } else {
                    Text("0")
                }
            }
            LabeledContent("Current Streak", value: "\(mode.currentStreak)")
            LabeledContent("Best Streak", value: "\(mode.bestStreak)")
            LabeledContent("Fastest Time", value: mode.bestTime.map(formatGameTime) ?? "—")
            LabeledContent("Average Time", value: mode.averageTime.map(formatGameTime) ?? "—")
            LabeledContent("Overall Streak", value: "\(stats.overall.current) (best \(stats.overall.best))")
            Button("Reset Stats for This Mode", role: .destructive) { isConfirmingReset = true }
                .disabled(mode.played == 0)
        } header: {
            // A bold title with the mode as a grey subtitle under it.
            VStack(alignment: .leading, spacing: 2) {
                Text("Stats")
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                Text(self.mode.name)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .textCase(nil)
        }
        .confirmationDialog(
            "Reset stats for \(self.mode.name)?",
            isPresented: $isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) { stats.reset(self.mode) }
        } message: {
            Text("Played, wins, streaks and times for this mode will be cleared. Your overall streak is kept.")
        }
    }
}
