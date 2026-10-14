import SwiftUI

enum ThemeStyle: String, CaseIterable, Identifiable, Codable {
    case classic
    case modern

    var id: Self { self }

    var displayName: String {
        switch self {
        case .classic: "Classic"
        case .modern: "Modern"
        }
    }
}

/// Everything a view needs to draw itself in the current look.
/// Resolved from (style × color scheme) and passed down through the environment.
struct Theme: Sendable {
    let palette: Palette
    let chrome: Chrome
    let renderer: any CellRenderer

    static func resolve(_ style: ThemeStyle, colorScheme: ColorScheme) -> Theme {
        switch style {
        case .classic: colorScheme == .dark ? .classicDark : .classicLight
        case .modern: colorScheme == .dark ? .modernDark : .modernLight
        }
    }
}

/// What only one look has. Views switch on this to pick their style, and the classic case
/// carries the colors only it uses.
enum Chrome: Sendable {
    /// 3D bevels, a one-point grid and red LED counters.
    case classic(ClassicColors)
    /// Flat rounded tiles; the shared palette covers it.
    case modern
}

extension EnvironmentValues {
    @Entry var theme: Theme = .classicLight
}
