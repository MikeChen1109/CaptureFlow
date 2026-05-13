import SwiftUI

struct CardRowView: View {
    let card: ActionCard

    var body: some View {
        CFCardContainer {
            HStack(alignment: .top, spacing: CFSpacing.medium) {
                icon

                VStack(alignment: .leading, spacing: CFSpacing.small) {
                    HStack(spacing: CFSpacing.small) {
                        Text(card.type.displayName)
                            .font(CFTypography.caption)
                            .foregroundStyle(CFColors.orangeHighlight)

                        Text(statusText)
                            .font(CFTypography.caption)
                            .foregroundStyle(statusTint)
                            .padding(.horizontal, CFSpacing.small)
                            .frame(height: 22)
                            .background(statusTint.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.pill, style: .continuous))
                    }

                    Text(card.title)
                        .font(CFTypography.headline)
                        .foregroundStyle(CFColors.textPrimary)
                        .lineLimit(2)

                    Text(card.updatedAt, style: .date)
                        .font(CFTypography.caption)
                        .foregroundStyle(CFColors.textSecondary)
                }
            }
        }
    }

    private var icon: some View {
        Image(systemName: systemImage)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(CFColors.background)
            .frame(width: 38, height: 38)
            .background(CFColors.primaryOrange)
            .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.medium, style: .continuous))
    }

    private var systemImage: String {
        switch card.type {
        case .auto:
            "sparkles"
        case .reminder:
            "checklist"
        case .calendar:
            "calendar"
        case .note:
            "note.text"
        case .shopping:
            "cart"
        case .job:
            "briefcase"
        }
    }

    private var statusText: String {
        card.status.rawValue.capitalized
    }

    private var statusTint: Color {
        switch card.status {
        case .pending:
            CFColors.warning
        case .saved:
            CFColors.info
        case .completed:
            CFColors.success
        case .archived:
            CFColors.textSecondary
        }
    }
}
