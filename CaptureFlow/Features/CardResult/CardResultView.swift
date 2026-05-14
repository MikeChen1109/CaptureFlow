import SwiftUI

struct CardResultView: View {
    @ObservedObject private var viewModel: CardResultViewModel
    @State private var isFinishing = false
    private let onFinish: ((ActionCard) -> Void)?
    private let onCancel: (() -> Void)?
    private let onRetry: (() -> Void)?
    private let revealedSectionCount: Int?
    private let isResultFullyRevealed: Bool

    init(
        viewModel: CardResultViewModel,
        onFinish: ((ActionCard) -> Void)? = nil,
        onCancel: (() -> Void)? = nil,
        onRetry: (() -> Void)? = nil,
        revealedSectionCount: Int? = nil,
        isResultFullyRevealed: Bool = true
    ) {
        self.viewModel = viewModel
        self.onFinish = onFinish
        self.onCancel = onCancel
        self.onRetry = onRetry
        self.revealedSectionCount = revealedSectionCount
        self.isResultFullyRevealed = isResultFullyRevealed
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CFSpacing.xLarge) {
                HeaderRow(card: viewModel.card)
                SectionStack(sectionStates: visibleSectionStates)

                if viewModel.isGenerationCompleted && isResultFullyRevealed {
                    AddFieldCard(viewModel: viewModel)
                        .padding(.top, -CFSpacing.small)
                        .transition(.cfSectionReveal)

                    ActionButtonsCard(
                        viewModel: viewModel,
                        isFinishing: isFinishing,
                        primaryActionTitle: primaryActionTitle,
                        reminderButtonTitle: reminderButtonTitle,
                        calendarButtonTitle: calendarButtonTitle,
                        onSaveTapped: saveAndFinishIfNeeded
                    )
                    .padding(.top, -CFSpacing.small)
                    .transition(.cfSectionReveal)
                }

                if let errorMessage = viewModel.errorMessage,
                   viewModel.generationStatus == .failed {
                    GenerationFailureCard(
                        message: errorMessage,
                        onRetry: onRetry,
                        onLeave: onCancel
                    )
                }
            }
            .padding(CFSpacing.large)
        }
        .background(CFColors.background.ignoresSafeArea())
        .navigationTitle("Card Result")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(onFinish != nil)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            if let onCancel {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .accessibilityLabel("Close")
                }
            }

        }
    }

    private var visibleSectionStates: [GeneratedSectionState] {
        if let revealedSectionCount {
            let completedStates = viewModel.sectionStates.filter { $0.content != nil }
            return Array(completedStates.prefix(max(revealedSectionCount, 0)))
        }

        let started = Array(viewModel.sectionStates.prefix { $0.status != .waiting })
        guard !started.isEmpty else {
            return viewModel.generationStatus == .generating
                ? Array(viewModel.sectionStates.prefix(1))
                : []
        }
        return started
    }

    private var primaryActionTitle: String {
        if viewModel.didSave {
            return onFinish == nil ? "Saved" : "Saved - Returning"
        }

        return onFinish == nil ? "Save to Inbox" : "Save & Finish"
    }

    private var reminderButtonTitle: String {
        viewModel.isCreatingReminder ? "Creating..." : "Create Reminder"
    }

    private var calendarButtonTitle: String {
        viewModel.isCreatingCalendar ? "Creating..." : "Create Calendar"
    }

    private func saveAndFinishIfNeeded() {
        Task {
            let didSave = await viewModel.save()
            guard didSave, let onFinish else {
                return
            }

            isFinishing = true
            try? await Task.sleep(for: .milliseconds(700))
            onFinish(viewModel.card)
        }
    }
}

private struct HeaderRow: View {
    let card: ActionCard

    var body: some View {
        HStack(alignment: .center, spacing: CFSpacing.small) {
            CardTypeBadge(cardType: card.type)

            Spacer(minLength: 0)
        }
    }
}

private struct SectionStack: View {
    let sectionStates: [GeneratedSectionState]

    var body: some View {
        VStack(alignment: .leading, spacing: CFSpacing.large) {
            ForEach(Array(sectionStates.enumerated()), id: \.element.id) { index, state in
                GeneratedSectionCard(state: state)
                    .transition(.cfSectionReveal)
                    .zIndex(Double(sectionStates.count - index))
            }
        }
    }
}

private extension AnyTransition {
    static var cfSectionReveal: AnyTransition {
        .asymmetric(
            insertion: .offset(y: 20)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.985, anchor: .top)),
            removal: .opacity
        )
    }
}

private struct AddFieldCard: View {
    @ObservedObject var viewModel: CardResultViewModel
    @State private var isPresentingAddFieldSheet = false
    @State private var recentlyDeleted: RemovedCustomField?
    @State private var undoDismissTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: CFSpacing.small) {
            ForEach(viewModel.customFields) { field in
                CustomFieldRow(field: field) {
                    guard let removed = viewModel.removeCustomField(id: field.id) else {
                        return
                    }
                    recentlyDeleted = removed
                    beginUndoDismissTimer()
                }
            }

            CFSecondaryButton(
                "Add Field",
                systemImage: "plus.circle.fill"
            ) {
                isPresentingAddFieldSheet = true
            }
            .padding(.top, viewModel.customFields.isEmpty ? 0 : CFSpacing.large - CFSpacing.small)

            if let recentlyDeleted {
                HStack(spacing: CFSpacing.small) {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CFColors.textSecondary)

                    Text("\(recentlyDeleted.field.type.displayName) deleted")
                        .font(CFTypography.caption)
                        .foregroundStyle(CFColors.textSecondary)

                    Spacer(minLength: 0)

                    Button("Undo") {
                        viewModel.restoreCustomField(recentlyDeleted)
                        self.recentlyDeleted = nil
                        undoDismissTask?.cancel()
                    }
                    .font(CFTypography.caption.weight(.semibold))
                    .foregroundStyle(CFColors.orangeHighlight)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, CFSpacing.medium)
                .padding(.vertical, CFSpacing.small)
                .background(CFColors.elevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.medium, style: .continuous))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: viewModel.customFields)
        .animation(.easeInOut(duration: 0.2), value: recentlyDeleted?.field.id)
        .sheet(isPresented: $isPresentingAddFieldSheet) {
            AddFieldBottomSheet { fieldType, value in
                viewModel.addCustomField(type: fieldType, value: value)
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
                recentlyDeleted = nil
            }
        }
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

private struct AddFieldBottomSheet: View {
    let onAddField: (CardResultCustomFieldType, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: CardResultCustomFieldType = .note
    @State private var textValue = ""
    @State private var dateValue = Date()

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
                                FieldTypeChip(
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

                    FieldPreviewCard(
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
                        onAddField(selectedType, value)
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
        switch selectedType {
        case .date:
            return Self.dateFormatter.string(from: dateValue)
        case .time:
            return Self.timeFormatter.string(from: dateValue)
        case .link:
            let trimmed = textValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return nil
            }
            return normalizedLink(from: trimmed)
        default:
            let trimmed = textValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
    }

    private var isAddDisabled: Bool {
        resolvedValue == nil
    }

    private var validationMessage: String? {
        switch selectedType {
        case .date, .time:
            return nil
        case .link:
            let trimmed = textValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return "Enter a link to continue."
            }
            return normalizedLink(from: trimmed) == nil ? "Enter a valid URL (for example https://example.com)." : nil
        default:
            return textValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Enter a value to continue." : nil
        }
    }

    private func normalizedLink(from input: String) -> String? {
        if let url = URL(string: input), url.scheme != nil, url.host != nil {
            return url.absoluteString
        }

        let withScheme = "https://\(input)"
        guard let url = URL(string: withScheme), url.host != nil else {
            return nil
        }

        return url.absoluteString
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct FieldTypeChip: View {
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

private struct FieldPreviewCard: View {
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

private struct CardTypeBadge: View {
    let cardType: CardType

    var body: some View {
        HStack(spacing: CFSpacing.xSmall) {
            Image(systemName: cardType.systemImage)
                .imageScale(.small)

            Text(cardType.displayName)
                .lineLimit(1)
        }
        .font(CFTypography.caption)
        .foregroundStyle(CFColors.background)
        .padding(.horizontal, CFSpacing.medium)
        .frame(height: 30)
        .background(CFColors.orangeHighlight)
        .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.pill, style: .continuous))
    }
}

private struct ActionButtonsCard: View {
    @ObservedObject var viewModel: CardResultViewModel
    let isFinishing: Bool
    let primaryActionTitle: String
    let reminderButtonTitle: String
    let calendarButtonTitle: String
    let onSaveTapped: () -> Void

    var body: some View {
        CFCardContainer {
            VStack(alignment: .leading, spacing: CFSpacing.medium) {
                GeneratedSectionHeader(
                    title: "Actions",
                    systemImage: "wand.and.stars",
                    status: .completed
                )

                CFPrimaryButton(
                    primaryActionTitle,
                    systemImage: viewModel.didSave ? "checkmark" : "tray.and.arrow.down.fill",
                    isLoading: viewModel.isSaving || isFinishing,
                    isDisabled: viewModel.didSave
                ) {
                    onSaveTapped()
                }

                if viewModel.showsExternalActions {
                    HStack(spacing: CFSpacing.medium) {
                        if viewModel.showsReminderAction {
                            CFSecondaryButton(
                                viewModel.didCreateReminder ? "Reminder Created" : reminderButtonTitle,
                                systemImage: viewModel.didCreateReminder ? "checkmark.circle.fill" : "bell.badge.fill",
                                tone: viewModel.didCreateReminder ? .success : .normal,
                                isDisabled: !viewModel.canCreateReminder || viewModel.didCreateReminder || viewModel.isCreatingReminder
                            ) {
                                Task {
                                    await viewModel.createReminder()
                                }
                            }
                        }

                        if viewModel.showsCalendarAction {
                            CFSecondaryButton(
                                viewModel.didCreateCalendar ? "Calendar Created" : calendarButtonTitle,
                                systemImage: viewModel.didCreateCalendar ? "checkmark.circle.fill" : "calendar.badge.plus",
                                tone: viewModel.didCreateCalendar ? .success : .normal,
                                isDisabled: !viewModel.canCreateCalendar || viewModel.didCreateCalendar || viewModel.isCreatingCalendar
                            ) {
                                Task {
                                    await viewModel.createCalendarEvent()
                                }
                            }
                        }
                    }

                    if let calendarUnavailableReason = viewModel.calendarActionState.unavailableReason {
                        Text(calendarUnavailableReason)
                            .font(CFTypography.caption)
                            .foregroundStyle(CFColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                CFSecondaryButton(
                    viewModel.didCopyMarkdown ? "Markdown Copied" : "Copy Markdown",
                    systemImage: viewModel.didCopyMarkdown ? "checkmark" : "doc.on.doc.fill",
                    tone: viewModel.didCopyMarkdown ? .success : .normal
                ) {
                    viewModel.copyMarkdown()
                }

                if let actionMessage = viewModel.actionMessage {
                    Text(actionMessage)
                        .font(CFTypography.callout)
                        .foregroundStyle(CFColors.success)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(CFTypography.callout)
                        .foregroundStyle(CFColors.destructive)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

private struct GenerationFailureCard: View {
    let message: String
    let onRetry: (() -> Void)?
    let onLeave: (() -> Void)?

    var body: some View {
        CFCardContainer {
            VStack(alignment: .leading, spacing: CFSpacing.medium) {
                Text(message)
                    .font(CFTypography.callout)
                    .foregroundStyle(CFColors.destructive)
                    .frame(maxWidth: .infinity, alignment: .leading)

                CFPrimaryButton(
                    "Retry",
                    systemImage: "arrow.clockwise",
                    isDisabled: onRetry == nil
                ) {
                    onRetry?()
                }

                if let onLeave {
                    CFSecondaryButton(
                        "Leave",
                        systemImage: "xmark"
                    ) {
                        onLeave()
                    }
                }
            }
        }
    }
}

private extension CardType {
    var systemImage: String {
        switch self {
        case .auto:
            "sparkles"
        case .reminder:
            "bell.badge.fill"
        case .calendar:
            "calendar.badge.plus"
        case .note:
            "note.text"
        case .shopping:
            "bag.fill"
        case .job:
            "briefcase.fill"
        }
    }
}
