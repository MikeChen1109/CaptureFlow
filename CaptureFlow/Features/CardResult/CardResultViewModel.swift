import Combine
import Foundation
import UIKit

@MainActor
final class CardResultViewModel: ObservableObject {
    @Published private(set) var card: ActionCard
    @Published private(set) var sectionStates: [GeneratedSectionState]
    @Published private(set) var generationStatus: CardGenerationStatus
    @Published private(set) var isSaving = false
    @Published private(set) var isCreatingReminder = false
    @Published private(set) var isCreatingCalendar = false
    @Published private(set) var didSave = false
    @Published private(set) var didCreateReminder = false
    @Published private(set) var didCreateCalendar = false
    @Published private(set) var didCopyMarkdown = false
    @Published private(set) var customFields: [CardResultCustomField] = []
    @Published var errorMessage: String?
    @Published var actionMessage: String?

    private(set) var generatedContent: GeneratedInsightCard?
    private(set) var savedInsightCard: SavedInsightCard?

    private let calendarActionResolver = CardResultCalendarActionResolver()
    private let cardRepository: any CardRepository
    private let reminderCreator: any ReminderCreating
    private let calendarCreator: any CalendarCreating

    private var sectionStateMachine: GeneratedSectionStateMachine

    init(
        card: ActionCard,
        cardRepository: any CardRepository,
        reminderCreator: any ReminderCreating,
        calendarCreator: any CalendarCreating
    ) {
        self.card = card
        self.generatedContent = nil
        self.savedInsightCard = nil
        self.cardRepository = cardRepository
        self.reminderCreator = reminderCreator
        self.calendarCreator = calendarCreator

        let sectionStateMachine = GeneratedSectionStateMachine()
        self.sectionStateMachine = sectionStateMachine
        self.sectionStates = sectionStateMachine.sectionStates
        self.generationStatus = sectionStateMachine.generationStatus
    }

    var isGenerationCompleted: Bool {
        generationStatus == .completed
    }

    var canCreateReminder: Bool {
        guard !isCreatingReminder, !didCreateReminder else {
            return false
        }

        return switch card {
        case .reminder, .shopping, .job:
            true
        case .calendar, .note:
            false
        }
    }

    var canCreateCalendar: Bool {
        !isCreatingCalendar && !didCreateCalendar && calendarActionState.request != nil
    }

    var calendarActionState: CardResultCalendarActionState {
        calendarActionResolver.actionState(
            for: card,
            customFields: customFields
        )
    }

    var showsReminderAction: Bool {
        canCreateReminder || didCreateReminder || isCreatingReminder
    }

    var showsCalendarAction: Bool {
        calendarActionState.isVisible || didCreateCalendar || isCreatingCalendar
    }

    var showsExternalActions: Bool {
        showsReminderAction || showsCalendarAction
    }

    func firstWaitingSection() -> GeneratedSectionState? {
        sectionStateMachine.firstWaitingSection
    }

    func completeGeneration(card: ActionCard, content: GeneratedInsightCard) {
        self.card = card
        generatedContent = content
        savedInsightCard = nil

        sectionStateMachine.complete(with: content)
        syncSectionState()
    }

    func failGeneration(_ error: Error) {
        sectionStateMachine.fail()
        syncSectionState()
        actionMessage = nil
        errorMessage = "Unable to build this insight: \(error.userFacingMessage)"
    }

    func resetForRetry(with card: ActionCard) {
        self.card = card
        generatedContent = nil
        savedInsightCard = nil
        customFields = []
        errorMessage = nil
        actionMessage = nil

        isSaving = false
        isCreatingReminder = false
        isCreatingCalendar = false
        didSave = false
        didCreateReminder = false
        didCreateCalendar = false
        didCopyMarkdown = false

        let resetStateMachine = GeneratedSectionStateMachine()
        sectionStateMachine = resetStateMachine
        syncSectionState()
    }

    func addCustomField(type: CardResultCustomFieldType, value: String) {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            return
        }

        customFields.append(
            CardResultCustomField(
                type: type,
                value: trimmedValue
            )
        )

        Task {
            await persistCustomFieldsIfNeeded()
        }
    }

    @discardableResult
    func removeCustomField(id: UUID) -> RemovedCardResultCustomField? {
        guard let index = customFields.firstIndex(where: { $0.id == id }) else {
            return nil
        }

        let field = customFields.remove(at: index)
        Task {
            await persistCustomFieldsIfNeeded()
        }
        return RemovedCardResultCustomField(field: field, originalIndex: index)
    }

    func restoreCustomField(_ removed: RemovedCardResultCustomField) {
        let index = min(max(removed.originalIndex, 0), customFields.count)
        customFields.insert(removed.field, at: index)
        Task {
            await persistCustomFieldsIfNeeded()
        }
    }

    func save() async -> SavedInsightCard? {
        guard !isSaving else {
            return nil
        }

        isSaving = true
        defer {
            isSaving = false
        }

        errorMessage = nil
        actionMessage = nil

        do {
            guard let generatedContent else {
                throw ServiceError.invalidGeneratedCard
            }

            let cardToSave = (savedInsightCard ?? SavedInsightCard(
                insight: generatedContent,
                actionCard: card
            ))
            .updatingCustomFields(customFields)
            let savedCard = try await cardRepository.save(cardToSave)
            savedInsightCard = savedCard
            customFields = savedCard.customFields
            if let actionCard = savedCard.actionCard {
                card = actionCard
            }
            didSave = true
            actionMessage = "Saved to local inbox."
        } catch {
            errorMessage = "Unable to save this card."
            return nil
        }

        return savedInsightCard
    }

    func copyMarkdown() {
        UIPasteboard.general.string = (generatedContent?.markdown ?? card.markdown)
            .appendingMarkdownCustomFields(customFields)
        didCopyMarkdown = true
        actionMessage = "Markdown copied."
        errorMessage = nil
    }

    func createReminder() async {
        guard !isCreatingReminder, !didCreateReminder else {
            return
        }

        guard canCreateReminder,
              let request = card.reminderRequestForCardResult()
        else {
            errorMessage = "This card type does not support reminders."
            return
        }

        isCreatingReminder = true
        defer {
            isCreatingReminder = false
        }

        errorMessage = nil
        actionMessage = nil

        do {
            let result = try await reminderCreator.createReminder(request)
            card = card.applyingReminderResult(result)
            if let savedInsightCard {
                try await persistIfNeeded(savedInsightCard.applyingReminderResult(result))
            }
            didCreateReminder = true
            actionMessage = "Reminder created."
        } catch {
            errorMessage = "Unable to create reminder: \(error.userFacingMessage)"
        }
    }

    func createCalendarEvent() async {
        guard !isCreatingCalendar, !didCreateCalendar else {
            return
        }

        guard let request = calendarActionState.request else {
            errorMessage = calendarActionState.unavailableReason ?? "This card type does not support calendar events."
            return
        }

        isCreatingCalendar = true
        defer {
            isCreatingCalendar = false
        }

        errorMessage = nil
        actionMessage = nil

        do {
            let result = try await calendarCreator.createCalendarEvent(request)
            card = card.applyingCalendarResult(result)
            if let savedInsightCard {
                try await persistIfNeeded(savedInsightCard.applyingCalendarResult(result))
            }
            didCreateCalendar = true
            actionMessage = "Calendar event created."
        } catch {
            errorMessage = "Unable to create calendar event: \(error.userFacingMessage)"
        }
    }

    private func syncSectionState() {
        sectionStates = sectionStateMachine.sectionStates
        generationStatus = sectionStateMachine.generationStatus
    }

    private func persistIfNeeded(_ card: SavedInsightCard) async throws {
        guard didSave else { return }
        let updatedCard = try await cardRepository.update(card)
        savedInsightCard = updatedCard
        customFields = updatedCard.customFields
        if let actionCard = updatedCard.actionCard {
            self.card = actionCard
        }
    }

    private func persistCustomFieldsIfNeeded() async {
        guard didSave, let savedInsightCard else { return }

        do {
            try await persistIfNeeded(savedInsightCard.updatingCustomFields(customFields))
            actionMessage = nil
            errorMessage = nil
        } catch {
            errorMessage = "Unable to save custom fields."
        }
    }
}

private extension Error {
    var userFacingMessage: String {
        if let serviceError = self as? ServiceError {
            return serviceError.userFacingMessage
        }

        return String(describing: self)
    }
}
