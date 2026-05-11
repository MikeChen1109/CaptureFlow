import SwiftUI

struct CFSecondaryButton: View {
    enum Tone {
        case normal
        case success
        case destructive
    }

    let title: String
    var systemImage: String?
    var tone: Tone
    var isDisabled: Bool
    let action: () -> Void

    init(
        _ title: String,
        systemImage: String? = nil,
        tone: Tone = .normal,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tone = tone
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
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.pill, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: CFCornerRadius.pill, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private var foregroundColor: Color {
        guard !isDisabled || tone != .normal else {
            return CFColors.textSecondary.opacity(0.55)
        }

        switch tone {
        case .normal:
            return CFColors.textPrimary
        case .success:
            return CFColors.success
        case .destructive:
            return CFColors.destructive
        }
    }

    private var backgroundColor: Color {
        guard !isDisabled || tone != .normal else {
            return CFColors.secondarySurface.opacity(0.72)
        }

        switch tone {
        case .normal:
            return CFColors.secondarySurface
        case .success:
            return CFColors.success.opacity(0.12)
        case .destructive:
            return CFColors.destructive.opacity(0.12)
        }
    }

    private var borderColor: Color {
        guard !isDisabled || tone != .normal else {
            return CFColors.border.opacity(0.7)
        }

        switch tone {
        case .normal:
            return CFColors.border
        case .success:
            return CFColors.success.opacity(0.38)
        case .destructive:
            return CFColors.destructive.opacity(0.38)
        }
    }
}
