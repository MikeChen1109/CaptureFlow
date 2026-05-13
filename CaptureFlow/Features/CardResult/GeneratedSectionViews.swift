import SwiftUI

struct GeneratedSectionCard: View {
    let state: GeneratedSectionState

    var body: some View {
        CFCardContainer {
            VStack(alignment: .leading, spacing: CFSpacing.large) {
                GeneratedSectionHeader(
                    title: state.sectionType.title,
                    systemImage: state.sectionType.systemImage,
                    status: state.status
                )

                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentTransition(.opacity)
            }
        }
        .opacity(state.status == .waiting ? 0.68 : 1)
        .overlay(alignment: .topTrailing) {
            GeneratedSectionCornerStatus(status: state.status)
                .padding(.top, CFSpacing.medium)
                .padding(.trailing, CFSpacing.medium)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state.content {
        case .summary(let summary):
            Text(summary)
                .font(CFTypography.body)
                .foregroundStyle(CFColors.textPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        case .plan(let title, let steps):
            VStack(alignment: .leading, spacing: CFSpacing.medium) {
                Text(title)
                    .font(CFTypography.headline)
                    .foregroundStyle(CFColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: CFSpacing.small) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        GeneratedPlanStepRow(index: index + 1, step: step)
                    }
                }
            }
        case .keyDetails(let fields):
            VStack(alignment: .leading, spacing: CFSpacing.small) {
                ForEach(Array(fields.enumerated()), id: \.offset) { _, field in
                    GeneratedFieldRow(field: field)
                }
            }
        case .missingInfo(let items):
            VStack(alignment: .leading, spacing: CFSpacing.small) {
                ForEach(items, id: \.self) { item in
                    GeneratedBulletRow(text: item, systemImage: "questionmark.circle.fill")
                }
            }
        case nil:
            Text(state.sectionType.waitingHint)
                .font(CFTypography.callout)
                .foregroundStyle(CFColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct GeneratedSectionHeader: View {
    let title: String
    let systemImage: String
    let status: GeneratedSectionStatus

    var body: some View {
        HStack(spacing: CFSpacing.medium) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(status.iconColor)
                .frame(width: 28, height: 28)
                .background(status.iconBackground)
                .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.small, style: .continuous))

            Text(title)
                .font(CFTypography.callout.weight(.semibold))
                .foregroundStyle(CFColors.textPrimary)

            Spacer(minLength: 0)
        }
    }
}

private struct GeneratedSectionCornerStatus: View {
    let status: GeneratedSectionStatus

    var body: some View {
        Group {
            switch status {
            case .waiting, .generating:
                ProgressView()
                    .controlSize(.mini)
                    .tint(CFColors.orangeHighlight)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CFColors.success)
            }
        }
        .frame(width: 20, height: 20)
        .padding(6)
        .background(CFColors.elevatedSurface.opacity(0.96))
        .clipShape(Circle())
    }
}

private struct GeneratedPlanStepRow: View {
    let index: Int
    let step: GeneratedPlanStep

    var body: some View {
        HStack(alignment: .top, spacing: CFSpacing.medium) {
            Text("\(index)")
                .font(CFTypography.caption.weight(.bold))
                .foregroundStyle(CFColors.background)
                .frame(width: 24, height: 24)
                .background(CFColors.orangeHighlight)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: CFSpacing.xSmall) {
                Text(step.title)
                    .font(CFTypography.callout.weight(.semibold))
                    .foregroundStyle(CFColors.textPrimary)

                Text(step.detail)
                    .font(CFTypography.caption)
                    .foregroundStyle(CFColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CFSpacing.medium)
        .background(CFColors.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.medium, style: .continuous))
    }
}

private struct GeneratedFieldRow: View {
    let field: GeneratedField

    var body: some View {
        HStack(alignment: .top, spacing: CFSpacing.medium) {
            Image(systemName: field.type.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(CFColors.orangeHighlight)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: CFSpacing.xSmall) {
                Text(field.label)
                    .font(CFTypography.caption)
                    .foregroundStyle(CFColors.textSecondary)

                Text(field.value)
                    .font(CFTypography.callout.weight(.semibold))
                    .foregroundStyle(CFColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CFSpacing.medium)
        .background(CFColors.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.medium, style: .continuous))
    }
}

private struct GeneratedBulletRow: View {
    let text: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .center, spacing: CFSpacing.medium) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(CFColors.warning)
                .frame(width: 24, height: 24)

            Text(text)
                .font(CFTypography.callout)
                .foregroundStyle(CFColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(CFSpacing.medium)
        .background(CFColors.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.medium, style: .continuous))
    }
}

private extension GeneratedSectionType {
    var title: String {
        switch self {
        case .summary:
            "Summary"
        case .plan:
            "Plan / Checklist"
        case .keyDetails:
            "Key Details"
        case .missingInfo:
            "Missing Info"
        }
    }

    var systemImage: String {
        switch self {
        case .summary:
            "sparkles"
        case .plan:
            "checklist"
        case .keyDetails:
            "tag.fill"
        case .missingInfo:
            "questionmark.circle.fill"
        }
    }

    var waitingHint: String {
        switch self {
        case .summary:
            "Drafting ready-to-use output..."
        case .plan:
            "Building a practical checklist..."
        case .keyDetails:
            "Collecting key entities..."
        case .missingInfo:
            "Finding remaining gaps..."
        }
    }
}

private extension GeneratedSectionStatus {
    var title: String {
        switch self {
        case .waiting:
            "Waiting"
        case .generating:
            "Generating"
        case .completed:
            "Done"
        }
    }

    var textColor: Color {
        switch self {
        case .waiting:
            CFColors.textSecondary
        case .generating:
            CFColors.orangeHighlight
        case .completed:
            CFColors.success
        }
    }

    var iconColor: Color {
        switch self {
        case .waiting:
            CFColors.textSecondary
        case .generating:
            CFColors.background
        case .completed:
            CFColors.background
        }
    }

    var iconBackground: Color {
        switch self {
        case .waiting:
            CFColors.elevatedSurface
        case .generating:
            CFColors.primaryOrange
        case .completed:
            CFColors.success
        }
    }

    var pillBackground: Color {
        switch self {
        case .waiting:
            CFColors.elevatedSurface
        case .generating:
            CFColors.primaryOrange.opacity(0.16)
        case .completed:
            CFColors.success.opacity(0.16)
        }
    }
}

private extension VisionActionType {
    var systemImage: String {
        switch self {
        case .save:
            "tray.and.arrow.down.fill"
        case .reminder:
            "bell.badge.fill"
        case .calendar:
            "calendar.badge.plus"
        case .copy:
            "doc.on.doc.fill"
        case .share:
            "square.and.arrow.up"
        case .compare:
            "arrow.left.arrow.right"
        case .followUp:
            "arrow.forward.circle.fill"
        case .custom:
            "sparkles"
        }
    }
}

private extension VisionEntityType {
    var systemImage: String {
        switch self {
        case .product:
            "bag.fill"
        case .price:
            "tag.fill"
        case .promotion:
            "percent"
        case .store:
            "storefront.fill"
        case .date:
            "calendar"
        case .time:
            "clock.fill"
        case .location:
            "mappin.and.ellipse"
        case .company:
            "building.2.fill"
        case .role:
            "person.text.rectangle.fill"
        case .skill:
            "list.bullet.rectangle"
        case .url:
            "link"
        case .contact:
            "person.crop.circle.badge.plus"
        case .note:
            "note.text"
        case .event:
            "calendar.badge.clock"
        case .unknown:
            "questionmark.circle.fill"
        }
    }
}
