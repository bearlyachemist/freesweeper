import Foundation

/// "42.3 s", or "2:05.4" past a minute.
func formatGameTime(_ seconds: Double) -> String {
    if seconds < 60 { return String(format: "%.1f s", seconds) }
    let minutes = Int(seconds) / 60
    return String(format: "%d:%04.1f", minutes, seconds - Double(minutes * 60))
}
