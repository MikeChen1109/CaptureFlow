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
                CardResultHeader(card: viewModel.card)
                GeneratedSectionStack(sectionStates: visibleSectionStates)

                if viewModel.isGenerationCompleted && isResultFullyRevealed {
                    CustomFieldsSection(viewModel: viewModel)
                        .padding(.top, -CFSpacing.small)
                        .transition(.cfSectionReveal)

                    CardResultActionsCard(
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
                    CardResultFailureCard(
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

private struct CardResultHeader: View {
    let card: ActionCard

    var body: some View {
        HStack(alignment: .center, spacing: CFSpacing.small) {
            CardTypeBadge(cardType: card.type)

            Spacer(minLength: 0)
        }
    }
}

private struct GeneratedSectionStack: View {
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

private struct CardResultActionsCard: View {
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

private struct CardResultFailureCard: View {
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
