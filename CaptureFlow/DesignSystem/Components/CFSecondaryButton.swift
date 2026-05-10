import SwiftUI

struct CFSecondaryButton: View {
    let title: String
    var systemImage: String?
    var isDisabled: Bool
    let action: () -> Void

    init(
        _ title: String,
        systemImage: String? = nil,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: CFSpacing.small) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .imageScale(.medium)
                }

                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .font(CFTypography.callout.weight(.semibold))
            .foregroundStyle(isDisabled ? CFColors.textSecondary.opacity(0.55) : CFColors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(CFColors.secondarySurface)
            .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.pill, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: CFCornerRadius.pill, style: .continuous)
                    .stroke(CFColors.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}
