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
                Text("\(Double(mines) / Double(width * height), format: .percent.precision(.fractionLength(0))) of cells are mines. Up to \(String(maxMines)) (\(Difficulty.maxDensity, format: .percent)).")
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

    /// A number field for the mine count, clamped to the allowed range as you type.
    private var minesControl: some View {
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
    }

    private func setMines(_ count: Int) {
        mines = clamped(count)
        minesText = "\(mines)"
    }

    private func clamped(_ count: Int) -> Int {
        min(max(count, 1), maxMines)
    }
}
