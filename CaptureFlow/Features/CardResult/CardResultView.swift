import SwiftUI

struct CardResultView: View {
    @StateObject private var viewModel: CardResultViewModel
    @State private var isFinishing = false
    private let onFinish: ((ActionCard) -> Void)?
    private let onCancel: (() -> Void)?

    init(
        viewModel: CardResultViewModel,
        onFinish: ((ActionCard) -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onFinish = onFinish
        self.onCancel = onCancel
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CFSpacing.xLarge) {
                header
                sectionStack

                if viewModel.isPartialGenerationComplete {
                    actionButtons
                        .transition(.move(edge: .bottom).combined(with: .opacity))
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
        .task {
            viewModel.startPartialGeneration()
        }
        .onDisappear {
            viewModel.cancelGeneration()
        }
        .animation(.snappy, value: viewModel.sectionStates)
        .animation(.snappy, value: viewModel.isPartialGenerationComplete)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: CFSpacing.small) {
            cardTypeBadge

            CFConfidenceBadge(
                level: viewModel.card.confidence,
                score: viewModel.card.confidenceScore
            )

            Spacer(minLength: 0)
        }
    }

    private var sectionStack: some View {
        VStack(alignment: .leading, spacing: CFSpacing.large) {
            ForEach(viewModel.sectionStates) { state in
                GeneratedSectionCard(
                    state: state,
                    personalNote: Binding(
                        get: { viewModel.personalNote },
                        set: viewModel.updatePersonalNote
                    )
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }

    private var cardTypeBadge: some View {
        HStack(spacing: CFSpacing.xSmall) {
            Image(systemName: cardTypeIcon)
                .imageScale(.small)

            Text(viewModel.card.type.displayName)
                .lineLimit(1)
        }
        .font(CFTypography.caption)
        .foregroundStyle(CFColors.background)
        .padding(.horizontal, CFSpacing.medium)
        .frame(height: 30)
        .background(CFColors.orangeHighlight)
        .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.pill, style: .continuous))
    }

    private var actionButtons: some View {
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

                HStack(spacing: CFSpacing.medium) {
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

    private var cardTypeIcon: String {
        switch viewModel.card.type {
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
