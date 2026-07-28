import SwiftUI

/// Colours lifted from the site's stylesheet so the app and web read as one product.
enum Theme {
    static let background = Color(hex: 0xFAF9F5)
    static let text = Color(hex: 0x1A1814)
    static let secondary = Color(hex: 0x6B6558)
    static let rule = Color(hex: 0xEDE9E0)

    static let purple = Color(hex: 0x5B16C4)
    static let magenta = Color(hex: 0xC11FD6)

    static let wordmark = LinearGradient(
        colors: [purple, magenta],
        startPoint: .leading,
        endPoint: .trailing
    )
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
