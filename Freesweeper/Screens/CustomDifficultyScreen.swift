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

    private var maxMines: Int { Difficulty.maxMines(width: width, height: height) }

    var body: some View {
        Form {
            Section {
                Stepper("Width: \(width)", value: $width, in: Difficulty.customSizeRange)
                Stepper("Height: \(height)", value: $height, in: Difficulty.customSizeRange)
                Stepper("Mines: \(mines)", value: $mines, in: 1...maxMines)
            } footer: {
                Text("\(Double(mines) / Double(width * height), format: .percent.precision(.fractionLength(0))) of cells are mines.")
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
        }
        .onAppear {
            width = settings.difficulty.width
            height = settings.difficulty.height
            mines = settings.difficulty.mines
        }
        .onChange(of: maxMines) { mines = min(mines, $1) }
    }
}
