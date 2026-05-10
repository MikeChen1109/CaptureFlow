import SwiftUI

struct CFEmptyStateView: View {
    let title: String
    let message: String
    var systemImage: String

    init(
        title: String,
        message: String,
        systemImage: String = "sparkles"
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
    }

    var body: some View {
        CFCardContainer {
            VStack(spacing: CFSpacing.large) {
                Image(systemName: systemImage)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(CFColors.orangeHighlight)
                    .frame(width: 64, height: 64)
                    .background(CFColors.primaryOrange.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.large, style: .continuous))

                VStack(spacing: CFSpacing.small) {
                    Text(title)
                        .font(CFTypography.headline)
                        .foregroundStyle(CFColors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(message)
                        .font(CFTypography.callout)
                        .foregroundStyle(CFColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}
