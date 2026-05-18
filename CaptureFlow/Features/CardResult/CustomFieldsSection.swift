import SwiftUI

struct CustomFieldsSection: View {
    let customFields: [CardResultCustomField]
    let onAddCustomField: (CardResultCustomFieldType, String) -> Void
    let onRemoveCustomField: (UUID) -> RemovedCardResultCustomField?
    let onRestoreCustomField: (RemovedCardResultCustomField) -> Void

    @State private var isPresentingAddCustomFieldSheet = false
    @State private var recentlyRemovedField: RemovedCardResultCustomField?
    @State private var undoDismissTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: CFSpacing.medium) {
            ForEach(customFields) { field in
                CustomFieldRow(field: field) {
                    guard let removed = onRemoveCustomField(field.id) else {
                        return
                    }
                    recentlyRemovedField = removed
                    beginUndoDismissTimer()
                }
            }

            CFSecondaryButton(
                "Add Field",
                systemImage: "plus.circle.fill"
            ) {
                isPresentingAddCustomFieldSheet = true
            }

            if let recentlyRemovedField {
                DeletedCustomFieldUndoRow(recentlyRemovedField: recentlyRemovedField) {
                    onRestoreCustomField(recentlyRemovedField)
                    self.recentlyRemovedField = nil
                    undoDismissTask?.cancel()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: customFields)
        .animation(.easeInOut(duration: 0.2), value: recentlyRemovedField?.field.id)
        .sheet(isPresented: $isPresentingAddCustomFieldSheet) {
            AddCustomFieldSheet { fieldType, value in
                onAddCustomField(fieldType, value)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private func beginUndoDismissTimer() {
        undoDismissTask?.cancel()
        undoDismissTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else {
                return
            }
            await MainActor.run {
                recentlyRemovedField = nil
            }
        }
    }
}

private struct DeletedCustomFieldUndoRow: View {
    let recentlyRemovedField: RemovedCardResultCustomField
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: CFSpacing.small) {
            Image(systemName: "trash")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(CFColors.textSecondary)

            Text("\(recentlyRemovedField.field.type.displayName) deleted")
                .font(CFTypography.caption)
                .foregroundStyle(CFColors.textSecondary)

            Spacer(minLength: 0)

            Button("Undo", action: onUndo)
                .font(CFTypography.caption.weight(.semibold))
                .foregroundStyle(CFColors.orangeHighlight)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, CFSpacing.medium)
        .padding(.vertical, CFSpacing.small)
        .background(CFColors.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.medium, style: .continuous))
    }
}

private struct CustomFieldRow: View {
    let field: CardResultCustomField
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: CFSpacing.medium) {
            Image(systemName: field.type.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(CFColors.orangeHighlight)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: CFSpacing.xSmall) {
                Text(field.type.displayName)
                    .font(CFTypography.caption)
                    .foregroundStyle(CFColors.textSecondary)

                Text(field.value)
                    .font(CFTypography.callout.weight(.semibold))
                    .foregroundStyle(CFColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(CFColors.textSecondary)
                    .padding(.top, 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete field")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CFSpacing.medium)
        .background(CFColors.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.medium, style: .continuous))
    }
}
