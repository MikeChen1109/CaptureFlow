import SwiftUI

struct CFConfidenceBadge: View {
    let level: ConfidenceLevel
    var score: Double?

    var body: some View {
        HStack(spacing: CFSpacing.xSmall) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)

            Text(label)
                .font(CFTypography.caption)
                .foregroundStyle(CFColors.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, CFSpacing.medium)
        .frame(height: 30)
        .background(tint.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.pill, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CFCornerRadius.pill, style: .continuous)
                .stroke(tint.opacity(0.45), lineWidth: 1)
        }
    }

    private var label: String {
        let base = switch level {
        case .low:
            "Low"
        case .medium:
            "Medium"
        case .high:
            "High"
        }

        guard let score else {
            return "\(base) confidence"
        }

        return "\(base) \(Int((score * 100).rounded()))%"
    }

    private var tint: Color {
        switch level {
        case .low:
            CFColors.textSecondary
        case .medium:
            CFColors.primaryOrange
        case .high:
            CFColors.orangeHighlight
        }
    }
}
