import SwiftUI
import SweeperKit

/// Pushed from Settings › Game. Starting a board calls `onStart` so Settings can close.
struct CustomDifficultyScreen: View {
    let onStart: () -> Void

    @Environment(GameFlow.self) private var flow
    @Environment(AppSettings.self) private var settings

    @State private var width = 16
    @State private var height = 16
    @State private var mines = 40
    /// What's typed in the mine field; `mines` follows it live, clamped to the allowed range.
    @State private var minesText = "40"
    @FocusState private var isEditingMines: Bool

    private var maxMines: Int { Difficulty.maxMines(width: width, height: height) }

    var body: some View {
        Form {
            Section {
                Stepper("Width: \(width)", value: $width, in: Difficulty.customSizeRange)
                Stepper("Height: \(height)", value: $height, in: Difficulty.customSizeRange)
                minesControl
            } footer: {
                Text("\(Double(mines) / Double(width * height), format: .percent.precision(.fractionLength(0))) of cells are mines (up to \(Difficulty.maxDensity, format: .percent)).")
            }
        }
        .navigationTitle("Custom Board")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Start") {
                    if flow.requestNewGame(.custom(width: width, height: height, mines: mines)) {
                        onStart()
                    }
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isEditingMines = false }
            }
        }
        .onAppear {
            width = settings.difficulty.width
            height = settings.difficulty.height
            setMines(settings.difficulty.mines)
        }
        .onChange(of: maxMines) { setMines(mines) }
        .onChange(of: minesText) {
            if let typed = Int(minesText) { mines = clamped(typed) }
        }
        .onChange(of: isEditingMines) {
            // Leaving the field tidies it: an empty or out-of-range entry shows the real count.
            if !isEditingMines { minesText = "\(mines)" }
        }
    }

    /// A slider for big moves and a number field for exact counts, kept in sync.
    private var minesControl: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Mines")
                Spacer()
                TextField("Mines", text: $minesText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                    .focused($isEditingMines)
            }
            Slider(
                value: Binding(
                    get: { Double(mines) },
                    set: { setMines(Int($0.rounded())) }
                ),
                in: 1...Double(maxMines),
                step: 1
            ) {
                Text("Mines")
            } minimumValueLabel: {
                Text("1")
            } maximumValueLabel: {
                // Plain digits, to match the field (interpolating an Int adds a grouping comma).
                Text(verbatim: String(maxMines))
            }
            .monospacedDigit()
        }
        .padding(.vertical, 4)
    }

    private func setMines(_ count: Int) {
        mines = clamped(count)
        minesText = "\(mines)"
    }

    private func clamped(_ count: Int) -> Int {
        min(max(count, 1), maxMines)
    }
}
