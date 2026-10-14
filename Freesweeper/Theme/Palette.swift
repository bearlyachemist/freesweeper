import SwiftUI

/// Colors every look uses.
struct Palette: Sendable {
    /// Behind the board and header.
    var background: Color
    /// Covered cells and classic window faces.
    var face: Color
    var revealed: Color
    /// A covered cell under the finger.
    var pressed: Color
    var exploded: Color
    /// Colors for the numbers 1–8 (index 0 is "1").
    var numbers: [Color]
    var ink: Color
    var mine: Color
    var mineHighlight: Color
    var flag: Color
    var wrongMark: Color
    var smiley: Color
    var smileyInk: Color
    var accent: Color
    /// Text and icons on an accent fill.
    var onAccent: Color
    /// Header buttons and counters.
    var buttonFill: Color
}

/// Colors only the classic look uses.
struct ClassicColors: Sendable {
    var bevelLight: Color
    var bevelDark: Color
    var gridLine: Color
    var ledBackground: Color
    var ledOn: Color
    var ledOff: Color
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
