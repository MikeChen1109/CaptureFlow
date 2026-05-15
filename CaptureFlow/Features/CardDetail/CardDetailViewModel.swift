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
    @Published var errorMessage: String?
    @Published var actionMessage: String?

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
        card?.supportsReminderAction == true || isCreatingReminder
    }

    var showsCalendarAction: Bool {
        card?.supportsCalendarAction == true || isCreatingCalendar
    }

    var canCreateReminder: Bool {
        card?.reminderRequest != nil && !isCreatingReminder
    }

    var canCreateCalendar: Bool {
        card?.calendarRequest != nil && !isCreatingCalendar
    }

    var didCreateReminder: Bool {
        card?.reminderExternalID != nil
    }

    var didCreateCalendar: Bool {
        card?.calendarExternalID != nil
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            card = try await cardRepository.fetchCard(id: cardID)
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

    func createReminder() async -> SavedInsightCard? {
        guard !isCreatingReminder,
              let card,
              let request = card.reminderRequest
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
}
