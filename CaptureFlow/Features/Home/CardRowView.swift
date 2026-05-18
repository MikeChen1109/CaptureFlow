import SwiftUI

struct CardRowView: View {
    let card: SavedInsightCard
    let onSelect: () -> Void

    var body: some View {
        cardContainer {
            Button(action: onSelect) {
                HStack(alignment: .top, spacing: CFSpacing.medium) {
                    icon

                    VStack(alignment: .leading, spacing: CFSpacing.small) {
                        Text(card.title)
                            .font(CFTypography.headline)
                            .foregroundStyle(CFColors.textPrimary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let summary {
                            Text(summary)
                                .font(CFTypography.callout)
                                .foregroundStyle(CFColors.textSecondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        metadataRow
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CFColors.placeholderText)
                        .padding(.top, 3)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func cardContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(CFSpacing.large)
            .background {
                RoundedRectangle(cornerRadius: CFCornerRadius.large, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                CFColors.elevatedSurface,
                                CFColors.surface
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: CFCornerRadius.large, style: .continuous)
                            .fill(iconTint.opacity(0.12))
                            .frame(width: 116, height: 84)
                            .blur(radius: 36)
                            .offset(x: -28, y: -28)
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.large, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: CFCornerRadius.large, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                iconTint.opacity(0.34),
                                CFColors.border.opacity(0.72)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.2), radius: 18, x: 0, y: 12)
    }

    private var icon: some View {
        Image(systemName: iconSystemName)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(CFColors.background)
            .frame(width: 38, height: 38)
            .background(iconTint)
            .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.medium, style: .continuous))
    }

    private var metadataRow: some View {
        HStack(spacing: CFSpacing.xSmall) {
            Image(systemName: "clock")
                .imageScale(.small)

            Text(card.updatedAt, style: .date)
                .lineLimit(1)
        }
        .font(CFTypography.caption)
        .foregroundStyle(CFColors.placeholderText)
    }

    private var summary: String? {
        card.insight.summary?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    private var iconSystemName: String {
        switch card.actionCard?.type {
        case .reminder:
            "bell.badge.fill"
        case .calendar:
            "calendar.badge.clock"
        case .note:
            "text.alignleft"
        case .shopping:
            "cart.fill"
        case .job:
            "briefcase.fill"
        case .auto, .none:
            "sparkles.rectangle.stack"
        }
    }

    private var iconTint: Color {
        switch card.actionCard?.type {
        case .calendar:
            CFColors.info
        case .shopping:
            CFColors.warning
        case .job:
            CFColors.success
        case .note:
            CFColors.textSecondary
        case .reminder, .auto, .none:
            CFColors.primaryOrange
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
