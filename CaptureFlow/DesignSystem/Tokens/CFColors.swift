import SwiftUI

enum CFColors {
    static let background = Color(hex: 0x0B0B0D)
    static let surface = Color(hex: 0x17171A)
    static let secondarySurface = Color(hex: 0x222228)
    static let primaryOrange = Color(hex: 0xFF7A1A)
    static let orangeHighlight = Color(hex: 0xFF9F45)
    static let textPrimary = Color(hex: 0xF5F5F7)
    static let textSecondary = Color(hex: 0xA1A1AA)
    static let border = Color(hex: 0x2F2F36)
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
