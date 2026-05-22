import Combine
import Foundation
import UIKit

@MainActor
final class CardDetailViewModel: ObservableObject {
    @Published private(set) var card: SavedInsightCard?
    @Published private(set) var isLoading = false
    @Published private(set) var isArchiving = false
    @Published private(set) var isDeleting = false
    @Published private(set) var isCreatingReminder = false
    @Published private(set) var isCreatingCalendar = false
    @Published private(set) var didCopyMarkdown = false
    @Published private(set) var customFields: [CardResultCustomField] = []
    @Published var errorMessage: String?
    @Published var actionMessage: String?

    private let customFieldValueResolver = CardResultCustomFieldValueResolver()
    private let cardID: UUID
    private let cardRepository: any CardRepository
    private let reminderCreator: any ReminderCreating
    private let calendarCreator: any CalendarCreating

    init(
        cardID: UUID,
        cardRepository: any CardRepository,
        reminderCreator: any ReminderCreating,
        calendarCreator: any CalendarCreating
    ) {
        self.cardID = cardID
        self.cardRepository = cardRepository
        self.reminderCreator = reminderCreator
        self.calendarCreator = calendarCreator
    }

    var showsExternalActions: Bool {
        showsReminderAction || showsCalendarAction
    }

    var showsReminderAction: Bool {
        card != nil || isCreatingReminder
    }

    var showsCalendarAction: Bool {
        card?.supportsCalendarAction == true || isCreatingCalendar
    }

    var canCreateReminder: Bool {
        reminderRequest != nil && !isCreatingReminder
    }

    var canCreateCalendar: Bool {
        card?.calendarRequest != nil && !isCreatingCalendar
    }

    var didCreateReminder: Bool {
        card?.effectiveReminderExternalID != nil
    }

    var didCreateCalendar: Bool {
        card?.effectiveCalendarExternalID != nil
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            card = try await cardRepository.fetchCard(id: cardID)
            customFields = card?.customFields ?? []
            if card == nil {
                errorMessage = "Insight not found."
            }
        } catch {
            errorMessage = "Unable to load this insight."
        }

        isLoading = false
    }

    func copyMarkdown() {
        guard let card else { return }
        UIPasteboard.general.string = card.markdown
        didCopyMarkdown = true
        actionMessage = "Markdown copied."
        errorMessage = nil
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
        actionMessage = nil
        errorMessage = nil

        Task {
            await persistCustomFields()
        }
    }

    @discardableResult
    func removeCustomField(id: UUID) -> RemovedCardResultCustomField? {
        guard let index = customFields.firstIndex(where: { $0.id == id }) else {
            return nil
        }

        let field = customFields.remove(at: index)
        Task {
            await persistCustomFields()
        }
        return RemovedCardResultCustomField(field: field, originalIndex: index)
    }

    func restoreCustomField(_ removed: RemovedCardResultCustomField) {
        let index = min(max(removed.originalIndex, 0), customFields.count)
        customFields.insert(removed.field, at: index)

        Task {
            await persistCustomFields()
        }
    }

    func createReminder() async -> SavedInsightCard? {
        guard !isCreatingReminder,
              let card,
              let request = reminderRequest
        else {
            errorMessage = "This insight does not have enough information for a reminder."
            return nil
        }

        isCreatingReminder = true
        errorMessage = nil
        actionMessage = nil

        do {
            let result = try await reminderCreator.createReminder(request)
            let updatedCard = try await cardRepository.update(card.applyingReminderResult(result))
            self.card = updatedCard
            actionMessage = "Reminder created."
            isCreatingReminder = false
            return updatedCard
        } catch {
            errorMessage = "Unable to create reminder."
        }

        isCreatingReminder = false
        return nil
    }

    func createCalendarEvent() async -> SavedInsightCard? {
        guard !isCreatingCalendar,
              let card,
              let request = card.calendarRequest
        else {
            errorMessage = "This insight does not have enough information for a calendar event."
            return nil
        }

        isCreatingCalendar = true
        errorMessage = nil
        actionMessage = nil

        do {
            let result = try await calendarCreator.createCalendarEvent(request)
            let updatedCard = try await cardRepository.update(card.applyingCalendarResult(result))
            self.card = updatedCard
            actionMessage = "Calendar event created."
            isCreatingCalendar = false
            return updatedCard
        } catch {
            errorMessage = "Unable to create calendar event."
        }

        isCreatingCalendar = false
        return nil
    }

    func archive() async -> SavedInsightCard? {
        isArchiving = true
        errorMessage = nil
        actionMessage = nil

        do {
            card = try await cardRepository.archiveCard(id: cardID)
            actionMessage = "Archived."
            isArchiving = false
            return card
        } catch {
            errorMessage = "Unable to archive this card."
            isArchiving = false
            return nil
        }
    }

    private var reminderRequest: ReminderCreationRequest? {
        guard let card,
              card.effectiveReminderExternalID == nil
        else {
            return nil
        }

        let baseRequest = card.reminderRequest ?? fallbackReminderRequest(for: card)
        return baseRequest.map(applyingCustomFields(to:))
    }

    private func fallbackReminderRequest(for card: SavedInsightCard) -> ReminderCreationRequest? {
        let title = card.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            return nil
        }

        return ReminderCreationRequest(
            sourceCardID: card.id,
            title: title,
            notes: card.insight.summary?.trimmingCharacters(in: .whitespacesAndNewlines).captureFlowNonEmpty
                ?? card.insight.sections
                    .sorted { $0.priority < $1.priority }
                    .map(\.content)
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines),
            dueDate: customReminderDate,
            location: customFieldValue(for: .location),
            priority: .medium
        )
    }

    private func applyingCustomFields(to request: ReminderCreationRequest) -> ReminderCreationRequest {
        var updatedRequest = request

        if let customReminderDate {
            updatedRequest.dueDate = customReminderDate
        }

        if let location = customFieldValue(for: .location) {
            updatedRequest.location = location
        }

        updatedRequest.notes = notesWithCustomFields(baseNotes: request.notes)
        return updatedRequest
    }

    private var customReminderDate: Date? {
        guard let customDate = customDate else {
            return nil
        }

        return customDate.combiningTime(from: customTime)
    }

    private var customDate: Date? {
        customFields
            .filter { $0.type == .date }
            .compactMap { customFieldValueResolver.date(from: $0.value) }
            .first
    }

    private var customTime: Date? {
        customFields
            .filter { $0.type == .time }
            .compactMap { customFieldValueResolver.time(from: $0.value) }
            .first
    }

    private func customFieldValue(for type: CardResultCustomFieldType) -> String? {
        customFields
            .first { $0.type == type }?
            .value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .captureFlowNonEmpty
    }

    private func notesWithCustomFields(baseNotes: String) -> String {
        var noteLines = baseNotes
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .captureFlowNonEmpty
            .map { [$0] } ?? []

        let detailFields = customFields.filter { field in
            switch field.type {
            case .date, .time, .location:
                false
            case .note, .link, .contact, .custom:
                true
            }
        }

        noteLines.append(
            contentsOf: detailFields.map { field in
                "\(field.type.displayName): \(field.value)"
            }
        )

        return noteLines.joined(separator: "\n")
    }

    func delete() async -> Bool {
        isDeleting = true
        errorMessage = nil
        actionMessage = nil

        do {
            try await cardRepository.deleteCard(id: cardID)
            card = nil
            actionMessage = "Deleted."
            isDeleting = false
            return true
        } catch {
            errorMessage = "Unable to delete this card."
            isDeleting = false
            return false
        }
    }

    private func persistCustomFields() async {
        guard let card else { return }

        do {
            self.card = try await cardRepository.update(card.updatingCustomFields(customFields))
            actionMessage = nil
            errorMessage = nil
        } catch {
            errorMessage = "Unable to save custom fields."
        }
    }
}
