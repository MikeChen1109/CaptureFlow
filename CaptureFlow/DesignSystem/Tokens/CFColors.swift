import SwiftUI

enum CFColors {
    static let background = Color(hex: 0x09090B)
    static let surface = Color(hex: 0x151518)
    static let elevatedSurface = Color(hex: 0x1D1D22)
    static let secondarySurface = Color(hex: 0x24242B)
    static let fieldSurface = Color(hex: 0x2A2A33)
    static let fieldBorder = Color(hex: 0x50505E)
    static let primaryOrange = Color(hex: 0xFF7A1A)
    static let orangeHighlight = Color(hex: 0xFF9F45)
    static let info = Color(hex: 0x5EA8FF)
    static let success = Color(hex: 0x48D17A)
    static let warning = Color(hex: 0xF4B740)
    static let textPrimary = Color(hex: 0xF5F5F7)
    static let textSecondary = Color(hex: 0xB8B8C4)
    static let placeholderText = Color(hex: 0x858592)
    static let border = Color(hex: 0x34343D)
    static let destructive = Color(hex: 0xFF5A5F)
}

private extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
