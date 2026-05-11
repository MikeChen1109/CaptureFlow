import SwiftUI

struct GeneratedSectionCard: View {
    let state: GeneratedSectionState
    @Binding var personalNote: String

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
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        GeneratedPlanStepRow(index: index + 1, step: step)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        case .recommendedActions(let actions):
            VStack(alignment: .leading, spacing: CFSpacing.small) {
                ForEach(actions) { action in
                    GeneratedActionRow(action: action)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        case .draft(let draft):
            VStack(alignment: .leading, spacing: CFSpacing.medium) {
                Text(draft.title)
                    .font(CFTypography.headline)
                    .foregroundStyle(CFColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(draft.body)
                    .font(CFTypography.body)
                    .foregroundStyle(CFColors.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        case .keyDetails(let fields):
            VStack(alignment: .leading, spacing: CFSpacing.small) {
                ForEach(fields) { field in
                    GeneratedFieldRow(field: field)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        case .missingInfo(let items):
            VStack(alignment: .leading, spacing: CFSpacing.small) {
                ForEach(items, id: \.self) { item in
                    GeneratedBulletRow(text: item, systemImage: "questionmark.circle.fill")
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        case .personalNote(let placeholder):
            ZStack(alignment: .topLeading) {
                if personalNote.isEmpty {
                    Text(placeholder)
                        .font(CFTypography.callout)
                        .foregroundStyle(CFColors.placeholderText)
                        .padding(.horizontal, CFSpacing.medium)
                        .padding(.vertical, CFSpacing.medium)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $personalNote)
                    .font(CFTypography.callout)
                    .foregroundStyle(CFColors.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, CFSpacing.small)
                    .padding(.vertical, CFSpacing.xSmall)
                    .frame(minHeight: 92)
            }
            .background(CFColors.fieldSurface)
            .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: CFCornerRadius.medium, style: .continuous)
                    .stroke(CFColors.fieldBorder, lineWidth: 1)
            }
        case nil:
            GeneratedWaitingRow()
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

            HStack(spacing: CFSpacing.xSmall) {
                if status == .generating {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(CFColors.orangeHighlight)
                }

                Text(status.title)
                    .font(CFTypography.caption)
                    .foregroundStyle(status.textColor)
            }
            .padding(.horizontal, CFSpacing.small)
            .frame(height: 26)
            .background(status.pillBackground)
            .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.pill, style: .continuous))
        }
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
        .padding(CFSpacing.medium)
        .background(CFColors.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.medium, style: .continuous))
    }
}

private struct GeneratedActionRow: View {
    let action: GeneratedAction

    var body: some View {
        HStack(alignment: .top, spacing: CFSpacing.medium) {
            Image(systemName: action.actionType.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(CFColors.orangeHighlight)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: CFSpacing.xSmall) {
                Text(action.title)
                    .font(CFTypography.callout.weight(.semibold))
                    .foregroundStyle(CFColors.textPrimary)

                Text(action.description)
                    .font(CFTypography.caption)
                    .foregroundStyle(CFColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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

            Spacer(minLength: 0)

            Text("\(Int(field.confidence * 100))%")
                .font(CFTypography.caption)
                .foregroundStyle(CFColors.textSecondary)
        }
        .padding(CFSpacing.medium)
        .background(CFColors.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.medium, style: .continuous))
    }
}

private struct GeneratedBulletRow: View {
    let text: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: CFSpacing.medium) {
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

private struct GeneratedWaitingRow: View {
    var body: some View {
        RoundedRectangle(cornerRadius: CFCornerRadius.medium, style: .continuous)
            .fill(CFColors.elevatedSurface.opacity(0.72))
            .frame(height: 44)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: CFCornerRadius.pill, style: .continuous)
                    .fill(CFColors.border)
                    .frame(width: 140, height: 10)
                    .padding(.horizontal, CFSpacing.medium)
            }
    }
}

private extension GeneratedSectionType {
    var title: String {
        switch self {
        case .summary:
            "Summary"
        case .plan:
            "Plan / Checklist"
        case .recommendedActions:
            "Recommended Actions"
        case .draft:
            "Draft Output"
        case .keyDetails:
            "Key Details"
        case .missingInfo:
            "Missing Info"
        case .personalNote:
            "Personal Note"
        }
    }

    var systemImage: String {
        switch self {
        case .summary:
            "sparkles"
        case .plan:
            "checklist"
        case .recommendedActions:
            "wand.and.stars"
        case .draft:
            "doc.text.fill"
        case .keyDetails:
            "tag.fill"
        case .missingInfo:
            "questionmark.circle.fill"
        case .personalNote:
            "note.text"
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
