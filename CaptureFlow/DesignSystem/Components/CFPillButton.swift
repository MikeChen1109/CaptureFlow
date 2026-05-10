import SwiftUI

struct CFPillButton: View {
    let title: String
    var systemImage: String?
    var isSelected: Bool
    let action: () -> Void

    init(
        _ title: String,
        systemImage: String? = nil,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: CFSpacing.xSmall) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .imageScale(.small)
                }

                Text(title)
                    .lineLimit(1)
            }
            .font(CFTypography.caption)
            .foregroundStyle(isSelected ? CFColors.background : CFColors.textPrimary)
            .padding(.horizontal, CFSpacing.medium)
            .frame(height: 34)
            .background(isSelected ? CFColors.orangeHighlight : CFColors.secondarySurface)
            .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.pill, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: CFCornerRadius.pill, style: .continuous)
                    .stroke(isSelected ? CFColors.orangeHighlight : CFColors.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
