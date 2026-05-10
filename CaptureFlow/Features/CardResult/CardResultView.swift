import SwiftUI

struct CardResultView: View {
    @StateObject private var viewModel: CardResultViewModel

    init(viewModel: CardResultViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CFSpacing.xLarge) {
                header
                generatedCard
                actions
            }
            .padding(CFSpacing.large)
        }
        .background(CFColors.background.ignoresSafeArea())
        .navigationTitle("Card Result")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: CFSpacing.small) {
            Text("Generated Card")
                .font(CFTypography.title)
                .foregroundStyle(CFColors.textPrimary)

            Text("Review the mock result before saving it to your local inbox.")
                .font(CFTypography.callout)
                .foregroundStyle(CFColors.textSecondary)
        }
    }

    private var generatedCard: some View {
        CFCardContainer {
            VStack(alignment: .leading, spacing: CFSpacing.large) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: CFSpacing.small) {
                        Text(viewModel.card.type.displayName)
                            .font(CFTypography.caption)
                            .foregroundStyle(CFColors.orangeHighlight)

                        Text(viewModel.card.title)
                            .font(CFTypography.headline)
                            .foregroundStyle(CFColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    CFConfidenceBadge(
                        level: viewModel.card.confidence,
                        score: viewModel.card.confidenceScore
                    )
                }

                Divider()
                    .overlay(CFColors.border)

                editableFields

                Divider()
                    .overlay(CFColors.border)

                VStack(alignment: .leading, spacing: CFSpacing.small) {
                    Text("Markdown Preview")
                        .font(CFTypography.caption)
                        .foregroundStyle(CFColors.orangeHighlight)

                    Text(viewModel.card.markdown)
                        .font(CFTypography.callout)
                        .foregroundStyle(CFColors.textSecondary)
                        .textSelection(.enabled)
                }
            }
        }
    }

    @ViewBuilder
    private var editableFields: some View {
        switch viewModel.card {
        case .reminder(let reminder):
            VStack(alignment: .leading, spacing: CFSpacing.medium) {
                textField(
                    "Title",
                    text: binding(get: { reminder.title }, set: viewModel.updateReminderTitle)
                )
                datePicker(
                    "Due",
                    date: Binding(
                        get: { reminder.dueDate ?? .now },
                        set: viewModel.updateReminderDueDate
                    )
                )
                textField(
                    "Location",
                    text: binding(get: { reminder.location ?? "" }, set: viewModel.updateReminderLocation)
                )
                priorityPicker(reminder.priority)
                textEditor(
                    "Notes",
                    text: binding(get: { reminder.notes }, set: viewModel.updateReminderNotes)
                )
            }
        case .calendar(let calendar):
            VStack(alignment: .leading, spacing: CFSpacing.medium) {
                textField(
                    "Title",
                    text: binding(get: { calendar.title }, set: viewModel.updateCalendarTitle)
                )
                datePicker(
                    "Start",
                    date: Binding(get: { calendar.startDate }, set: viewModel.updateCalendarStartDate)
                )
                datePicker(
                    "End",
                    date: Binding(get: { calendar.endDate }, set: viewModel.updateCalendarEndDate)
                )
                textField(
                    "Location",
                    text: binding(get: { calendar.location ?? "" }, set: viewModel.updateCalendarLocation)
                )
                textEditor(
                    "Notes",
                    text: binding(get: { calendar.notes }, set: viewModel.updateCalendarNotes)
                )
            }
        case .note(let note):
            VStack(alignment: .leading, spacing: CFSpacing.medium) {
                textField(
                    "Title",
                    text: binding(get: { note.title }, set: viewModel.updateNoteTitle)
                )
                textEditor(
                    "Summary",
                    text: binding(get: { note.summary }, set: viewModel.updateNoteSummary)
                )
                textEditor(
                    "Key Points",
                    text: binding(get: { note.bullets.joined(separator: "\n") }, set: viewModel.updateNoteBullets)
                )
                textEditor(
                    "Todos",
                    text: binding(get: { note.todos.joined(separator: "\n") }, set: viewModel.updateNoteTodos)
                )
            }
        case .shopping(let shopping):
            VStack(alignment: .leading, spacing: CFSpacing.medium) {
                textField(
                    "Product",
                    text: binding(get: { shopping.productName }, set: viewModel.updateShoppingProductName)
                )
                textField(
                    "Price",
                    text: binding(get: { shopping.price ?? "" }, set: viewModel.updateShoppingPrice)
                )
                textField(
                    "Merchant",
                    text: binding(get: { shopping.merchant ?? "" }, set: viewModel.updateShoppingMerchant)
                )
                textField(
                    "Offer",
                    text: binding(get: { shopping.offer ?? "" }, set: viewModel.updateShoppingOffer)
                )
                datePicker(
                    "Reminder",
                    date: Binding(get: { shopping.reminderDate ?? .now }, set: viewModel.updateShoppingReminderDate)
                )
                textEditor(
                    "Notes",
                    text: binding(get: { shopping.notes }, set: viewModel.updateShoppingNotes)
                )
            }
        case .job(let job):
            VStack(alignment: .leading, spacing: CFSpacing.medium) {
                textField(
                    "Company",
                    text: binding(get: { job.company }, set: viewModel.updateJobCompany)
                )
                textField(
                    "Role",
                    text: binding(get: { job.role }, set: viewModel.updateJobRole)
                )
                textEditor(
                    "Skills",
                    text: binding(get: { job.skills.joined(separator: "\n") }, set: viewModel.updateJobSkills)
                )
                textField(
                    "Contact",
                    text: binding(get: { job.contact ?? "" }, set: viewModel.updateJobContact)
                )
                textField(
                    "Next Action",
                    text: binding(get: { job.nextAction }, set: viewModel.updateJobNextAction)
                )
                datePicker(
                    "Follow Up",
                    date: Binding(get: { job.followUpDate ?? .now }, set: viewModel.updateJobFollowUpDate)
                )
                textEditor(
                    "Notes",
                    text: binding(get: { job.notes }, set: viewModel.updateJobNotes)
                )
            }
        }
    }

    private var actions: some View {
        VStack(spacing: CFSpacing.medium) {
            CFPrimaryButton(
                viewModel.didSave ? "Saved" : "Save to Inbox",
                systemImage: viewModel.didSave ? "checkmark" : "tray.and.arrow.down.fill",
                isLoading: viewModel.isSaving,
                isDisabled: viewModel.didSave
            ) {
                Task {
                    await viewModel.save()
                }
            }

            HStack(spacing: CFSpacing.medium) {
                CFSecondaryButton(
                    viewModel.didCreateReminder ? "Reminder Created" : reminderButtonTitle,
                    systemImage: viewModel.didCreateReminder ? "checkmark.circle.fill" : "bell.badge.fill",
                    isDisabled: !viewModel.canCreateReminder || viewModel.didCreateReminder || viewModel.isCreatingReminder
                ) {
                    Task {
                        await viewModel.createReminder()
                    }
                }

                CFSecondaryButton(
                    viewModel.didCreateCalendar ? "Calendar Created" : calendarButtonTitle,
                    systemImage: viewModel.didCreateCalendar ? "checkmark.circle.fill" : "calendar.badge.plus",
                    isDisabled: !viewModel.canCreateCalendar || viewModel.didCreateCalendar || viewModel.isCreatingCalendar
                ) {
                    Task {
                        await viewModel.createCalendarEvent()
                    }
                }
            }

            CFSecondaryButton(
                viewModel.didCopyMarkdown ? "Markdown Copied" : "Copy Markdown",
                systemImage: viewModel.didCopyMarkdown ? "checkmark" : "doc.on.doc.fill"
            ) {
                viewModel.copyMarkdown()
            }

            if let actionMessage = viewModel.actionMessage {
                Text(actionMessage)
                    .font(CFTypography.callout)
                    .foregroundStyle(CFColors.orangeHighlight)
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

    private var reminderButtonTitle: String {
        viewModel.isCreatingReminder ? "Creating..." : "Create Reminder"
    }

    private var calendarButtonTitle: String {
        viewModel.isCreatingCalendar ? "Creating..." : "Create Calendar"
    }

    private func binding(
        get: @escaping () -> String,
        set: @escaping (String) -> Void
    ) -> Binding<String> {
        Binding(get: get, set: set)
    }

    private func textField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: CFSpacing.xSmall) {
            fieldLabel(title)

            TextField(title, text: text)
                .font(CFTypography.callout)
                .foregroundStyle(CFColors.textPrimary)
                .padding(.horizontal, CFSpacing.medium)
                .frame(height: 46)
                .background(CFColors.secondarySurface)
                .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.medium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: CFCornerRadius.medium, style: .continuous)
                        .stroke(CFColors.border, lineWidth: 1)
                }
        }
    }

    private func textEditor(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: CFSpacing.xSmall) {
            fieldLabel(title)

            TextEditor(text: text)
                .font(CFTypography.callout)
                .foregroundStyle(CFColors.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, CFSpacing.small)
                .padding(.vertical, CFSpacing.xSmall)
                .frame(minHeight: 96)
                .background(CFColors.secondarySurface)
                .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.medium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: CFCornerRadius.medium, style: .continuous)
                        .stroke(CFColors.border, lineWidth: 1)
                }
        }
    }

    private func datePicker(_ title: String, date: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: CFSpacing.xSmall) {
            fieldLabel(title)

            DatePicker(title, selection: date)
                .labelsHidden()
                .tint(CFColors.primaryOrange)
                .padding(CFSpacing.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(CFColors.secondarySurface)
                .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.medium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: CFCornerRadius.medium, style: .continuous)
                        .stroke(CFColors.border, lineWidth: 1)
                }
        }
    }

    private func priorityPicker(_ priority: ReminderCard.Priority) -> some View {
        VStack(alignment: .leading, spacing: CFSpacing.xSmall) {
            fieldLabel("Priority")

            Picker(
                "Priority",
                selection: Binding(
                    get: { priority },
                    set: viewModel.updateReminderPriority
                )
            ) {
                ForEach(ReminderCard.Priority.allCases) { priority in
                    Text(priority.rawValue.capitalized)
                        .tag(priority)
                }
            }
            .pickerStyle(.segmented)
            .tint(CFColors.primaryOrange)
        }
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(CFTypography.caption)
            .foregroundStyle(CFColors.textSecondary)
    }
}
