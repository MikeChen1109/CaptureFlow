import SwiftUI

struct CFPrimaryButton: View {
    let title: String
    var systemImage: String?
    var isLoading: Bool
    var isDisabled: Bool
    let action: () -> Void

    init(
        _ title: String,
        systemImage: String? = nil,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: CFSpacing.small) {
                if isLoading {
                    ProgressView()
                        .tint(CFColors.background)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .imageScale(.medium)
                }

                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .font(CFTypography.headline)
            .foregroundStyle(CFColors.background)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background((isDisabled || isLoading) ? CFColors.primaryOrange.opacity(0.45) : CFColors.primaryOrange)
            .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.pill, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
    }
}
