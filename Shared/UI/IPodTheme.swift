import SwiftUI

struct IPodTheme {
    // MARK: - Background
    static let backgroundTop = Color(red: 0.91, green: 0.91, blue: 0.91)    // #E8E8E8
    static let backgroundBottom = Color(red: 0.82, green: 0.82, blue: 0.82) // #D0D0D0
    static var backgroundGradient: LinearGradient {
        LinearGradient(colors: [backgroundTop, backgroundBottom], startPoint: .top, endPoint: .bottom)
    }

    // MARK: - Highlight (selection bar)
    static let highlightStart = Color(red: 0.23, green: 0.51, blue: 0.96)   // #3B82F6
    static let highlightEnd = Color(red: 0.12, green: 0.25, blue: 0.69)     // #1E40AF
    static var highlightGradient: LinearGradient {
        LinearGradient(colors: [highlightStart, highlightEnd], startPoint: .leading, endPoint: .trailing)
    }

    // MARK: - Text
    static let textPrimary = Color.black
    static let textSecondary = Color(white: 0.4)
    static let textOnHighlight = Color.white

    // MARK: - Chrome
    static let separatorColor = Color(white: 0.75)
    static let titleBarTop = Color(white: 0.88)
    static let titleBarBottom = Color(white: 0.78)
    static var titleBarGradient: LinearGradient {
        LinearGradient(colors: [titleBarTop, titleBarBottom], startPoint: .top, endPoint: .bottom)
    }

    // MARK: - Progress bar
    static let progressBackground = Color(white: 0.80)
    static let progressFill = Color(red: 0.23, green: 0.51, blue: 0.96)

    // MARK: - Fonts
    static func font(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Helvetica Neue", size: size).weight(weight)
    }
}
