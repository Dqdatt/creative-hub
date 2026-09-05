import SwiftUI

enum CHColors {
    static let background = Color(hex: 0xF3F5FB)
    static let card = Color.white.opacity(0.80)
    static let cardSolid = Color.white
    static let ink = Color(hex: 0x111522)
    static let muted = Color(hex: 0x707B93)
    static let line = Color(red: 82 / 255, green: 96 / 255, blue: 132 / 255).opacity(0.13)
    static let purple = Color(hex: 0x7256FF)
    static let blue = Color(hex: 0x4E8CFF)
    static let green = Color(hex: 0x21BF6B)
    static let orange = Color(hex: 0xFF9C2A)
    static let red = Color(hex: 0xFF5B65)
    static let glass = Color.white.opacity(0.58)
    static let glassStrong = Color.white.opacity(0.72)

    static let primaryGradient = LinearGradient(
        colors: [purple, blue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let appBackground = LinearGradient(
        colors: [Color(hex: 0xEEF2FA), Color(hex: 0xF8F9FD), Color(hex: 0xEEF3FB)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }

    init?(hexString: String) {
        let normalized = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "# ").union(.whitespacesAndNewlines))
        guard normalized.count == 6, let value = UInt(normalized, radix: 16) else {
            return nil
        }
        self.init(hex: value)
    }
}
