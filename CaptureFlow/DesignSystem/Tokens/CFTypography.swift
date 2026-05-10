import SwiftUI

enum CFTypography {
    static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
    static let title = Font.system(size: 24, weight: .semibold, design: .rounded)
    static let headline = Font.system(size: 18, weight: .semibold, design: .rounded)
    static let body = Font.system(size: 16, weight: .regular, design: .default)
    static let callout = Font.system(size: 14, weight: .regular, design: .default)
    static let caption = Font.system(size: 12, weight: .medium, design: .default)
}
