import SwiftUI
import UIKit

/// Colours lifted from the site's stylesheet so the app and web read as one
/// product, with dark-mode variants so the app follows the system appearance.
enum Theme {
    static let background = Color(light: 0xFAF9F5, dark: 0x161412)
    static let text = Color(light: 0x1A1814, dark: 0xF2EFE8)
    static let secondary = Color(light: 0x6B6558, dark: 0xA8A296)
    static let rule = Color(light: 0xEDE9E0, dark: 0x2C2925)
    static let eyebrow = Color(light: 0x8A8577, dark: 0x8F8A7D)

    static let purple = Color(light: 0x5B16C4, dark: 0x9B5BFF)
    static let magenta = Color(light: 0xC11FD6, dark: 0xD65BE8)

    static let wordmark = LinearGradient(
        colors: [purple, Color(light: 0xA020C4, dark: 0xB847DB), magenta],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// The gradient utility bar keeps its saturated brand colours in both modes.
    static let headerGradient = LinearGradient(
        colors: [Color(hex: 0x5B16C4), Color(hex: 0xC11FD6)],
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

    /// A dynamic colour that resolves per the system's light/dark appearance.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}
