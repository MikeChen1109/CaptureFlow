import SwiftUI

struct CFCardContainer<Content: View>: View {
    private let padding: CGFloat
    private let content: Content

    init(
        padding: CGFloat = CFSpacing.large,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CFColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.large, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: CFCornerRadius.large, style: .continuous)
                    .stroke(CFColors.border, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 10)
    }
}
