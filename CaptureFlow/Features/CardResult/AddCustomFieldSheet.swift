import SwiftUI

struct AddCustomFieldSheet: View {
    let onAddCustomField: (CardResultCustomFieldType, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: CardResultCustomFieldType = .note
    @State private var textValue = ""
    @State private var dateValue = Date()

    private let fieldValueResolver = CardResultCustomFieldValueResolver()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CFSpacing.large) {
                    VStack(alignment: .leading, spacing: CFSpacing.xSmall) {
                        Text("Select a field type")
                            .font(CFTypography.callout.weight(.semibold))
                            .foregroundStyle(CFColors.textPrimary)

                        Text(selectedType.helperDescription)
                            .font(CFTypography.caption)
                            .foregroundStyle(CFColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: CFSpacing.small) {
                            ForEach(CardResultCustomFieldType.allCases) { type in
                                CustomFieldTypeChip(
                                    type: type,
                                    isSelected: selectedType == type
                                ) {
                                    selectedType = type
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    fieldInput

                    CustomFieldPreview(
                        type: selectedType,
                        value: resolvedValue
                    )
                }
                .padding(CFSpacing.large)
            }
            .background(CFColors.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: CFSpacing.small) {
                    if let validationMessage {
                        Text(validationMessage)
                            .font(CFTypography.caption)
                            .foregroundStyle(CFColors.textSecondary)
                    }

                    CFPrimaryButton(
                        "Add Field",
                        systemImage: "checkmark",
                        isDisabled: isAddDisabled
                    ) {
                        guard let value = resolvedValue else {
                            return
                        }
                        onAddCustomField(selectedType, value)
                        dismiss()
                    }
                }
                .padding(.horizontal, CFSpacing.large)
                .padding(.top, CFSpacing.small)
                .padding(.bottom, CFSpacing.medium)
                .background(CFColors.background)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var fieldInput: some View {
        switch selectedType {
        case .date:
            DatePicker(
                "Date",
                selection: $dateValue,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(CFColors.orangeHighlight)
        case .time:
            DatePicker(
                "Time",
                selection: $dateValue,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .tint(CFColors.orangeHighlight)
            .frame(maxWidth: .infinity)
        default:
            TextField(selectedType.placeholder, text: $textValue)
                .font(CFTypography.callout)
                .foregroundStyle(CFColors.textPrimary)
                .textInputAutocapitalization(.sentences)
                .keyboardType(selectedType.keyboardType)
                .textContentType(selectedType.textContentType)
                .autocorrectionDisabled(selectedType == .link)
                .padding(.horizontal, CFSpacing.medium)
                .frame(height: 48)
                .background(CFColors.fieldSurface)
                .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.medium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: CFCornerRadius.medium, style: .continuous)
                        .stroke(CFColors.fieldBorder, lineWidth: 1)
                }
        }
    }

    private var resolvedValue: String? {
        fieldValueResolver.resolvedValue(
            for: selectedType,
            textValue: textValue,
            dateValue: dateValue
        )
    }

    private var isAddDisabled: Bool {
        resolvedValue == nil
    }

    private var validationMessage: String? {
        fieldValueResolver.validationMessage(for: selectedType, textValue: textValue)
    }
}

private struct CustomFieldTypeChip: View {
    let type: CardResultCustomFieldType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: CFSpacing.xSmall) {
                Image(systemName: type.systemImage)
                    .font(.system(size: 12, weight: .semibold))

                Text(type.displayName)
                    .lineLimit(1)
            }
            .font(CFTypography.caption)
            .foregroundStyle(isSelected ? CFColors.background : CFColors.textPrimary)
            .padding(.horizontal, CFSpacing.medium)
            .frame(height: 34)
            .background(isSelected ? CFColors.orangeHighlight : CFColors.secondarySurface)
            .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.pill, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: CFCornerRadius.pill, style: .continuous)
                    .stroke(isSelected ? CFColors.orangeHighlight : CFColors.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct CustomFieldPreview: View {
    let type: CardResultCustomFieldType
    let value: String?

    var body: some View {
        VStack(alignment: .leading, spacing: CFSpacing.xSmall) {
            Text("Preview")
                .font(CFTypography.caption)
                .foregroundStyle(CFColors.textSecondary)

            HStack(alignment: .center, spacing: CFSpacing.small) {
                Image(systemName: type.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CFColors.orangeHighlight)

                Text(type.displayName)
                    .font(CFTypography.caption)
                    .foregroundStyle(CFColors.textSecondary)

                Text("•")
                    .font(CFTypography.caption)
                    .foregroundStyle(CFColors.textSecondary)

                Text(value ?? "Waiting for value")
                    .font(CFTypography.callout.weight(.semibold))
                    .foregroundStyle(value == nil ? CFColors.placeholderText : CFColors.textPrimary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CFSpacing.medium)
        .background(CFColors.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CFCornerRadius.medium, style: .continuous)
                .stroke(CFColors.border, lineWidth: 1)
        }
    }
}
