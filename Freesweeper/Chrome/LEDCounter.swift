import SwiftUI

/// The red seven-segment display used for the mine counter and the timer.
struct LEDCounter: View {
    let value: Int
    let digits: Int
    let colors: ClassicColors

    @Environment(\.compactHeader) private var compact

    private static let digit = CGSize(width: 15, height: 27)
    private static let compactDigit = CGSize(width: 12, height: 22)
    private static let spacing: CGFloat = 2

    var body: some View {
        let colors = colors
        let characters = Self.characters(for: value, digits: digits)
        let digit = compact ? Self.compactDigit : Self.digit
        Canvas { context, _ in
            for (i, character) in characters.enumerated() {
                let rect = CGRect(
                    x: CGFloat(i) * (digit.width + Self.spacing),
                    y: 0,
                    width: digit.width,
                    height: digit.height
                )
                SevenSegment.draw(character, in: rect, on: colors.ledOn, off: colors.ledOff, context: context)
            }
        }
        .frame(
            width: digit.width * CGFloat(digits) + Self.spacing * CGFloat(digits - 1),
            height: digit.height
        )
        .padding(3)
        .background(colors.ledBackground)
        .bevel(.sunken, width: 1, colors: colors)
    }

    /// Exactly `digits` characters, zero-padded and clamped to what fits.
    /// Negative values keep one place for the sign, e.g. "-07" with three digits.
    nonisolated static func characters(for value: Int, digits: Int) -> [Character] {
        let largest = Int(pow(10, Double(digits))) - 1
        let smallest = -(Int(pow(10, Double(digits - 1))) - 1)
        let clamped = min(max(value, smallest), largest)
        let magnitude = String(abs(clamped))
        let width = clamped < 0 ? digits - 1 : digits
        let padded = String(repeating: "0", count: max(0, width - magnitude.count)) + magnitude
        return Array(clamped < 0 ? "-" + padded : padded)
    }
}
