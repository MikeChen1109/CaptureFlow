import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var cards: [SavedInsightCard] = []
    @Published private(set) var creditBalance: CreditBalance?
    @Published private(set) var isLoading = false
    @Published private(set) var hasAttemptedInitialLoad = false
    @Published private(set) var creatingReminderCardID: UUID?
    @Published private(set) var creatingCalendarCardID: UUID?
    @Published var errorMessage: String?
    @Published private(set) var actionMessage: String?

    private let cardRepository: any CardRepository
    private let creditProvider: any CreditProviding
    private let reminderCreator: any ReminderCreating
    private let calendarCreator: any CalendarCreating
    private var didCompleteInitialLoad: Bool

    init(
        cardRepository: any CardRepository,
        creditProvider: any CreditProviding,
        reminderCreator: any ReminderCreating,
        calendarCreator: any CalendarCreating
    ) {
        self.cardRepository = cardRepository
        self.creditProvider = creditProvider
        self.reminderCreator = reminderCreator
        self.calendarCreator = calendarCreator
        self.didCompleteInitialLoad = false
    }

    convenience init(container: AppContainer) {
        self.init(
            cardRepository: container.cardRepository,
            creditProvider: container.creditProvider,
            reminderCreator: container.reminderCreator,
            calendarCreator: container.calendarCreator
        )
    }

    func loadIfNeeded() async {
        guard !didCompleteInitialLoad else {
            return
        }

        await load(force: false)
    }

    func load(force: Bool = true) async {
        guard !isLoading else {
            return
        }
        guard force || !didCompleteInitialLoad else {
            return
        }

        isLoading = true
        errorMessage = nil
        actionMessage = nil

        do {
            async let cards = cardRepository.fetchRecentCards(limit: 20)
            async let balance = creditProvider.currentBalance()

            self.cards = try await cards
            self.creditBalance = try await balance
            didCompleteInitialLoad = true
        } catch {
            errorMessage = "Unable to load inbox."
        }

        hasAttemptedInitialLoad = true
        isLoading = false
    }

    func refresh() async {
        await load(force: true)
    }

    func removeCardLocally(_ cardID: UUID) {
        cards.removeAll { $0.id == cardID }
    }

    func applyUpdatedCard(_ card: SavedInsightCard) {
        if card.status == .archived {
            removeCardLocally(card.id)
        } else {
            replaceCard(card)
        }
    }

    func createReminder(for cardID: UUID) async {
        guard creatingReminderCardID == nil,
              let card = cards.first(where: { $0.id == cardID }),
              let request = card.reminderRequest
        else {
            errorMessage = "This insight does not have enough information for a reminder."
            return
        }

        creatingReminderCardID = cardID
        errorMessage = nil
        actionMessage = nil

        do {
            let result = try await reminderCreator.createReminder(request)
            let updatedCard = try await cardRepository.update(card.applyingReminderResult(result))
            replaceCard(updatedCard)
            actionMessage = "Reminder created."
        } catch {
            errorMessage = "Unable to create reminder."
        }

        creatingReminderCardID = nil
    }

    func createCalendarEvent(for cardID: UUID) async {
        guard creatingCalendarCardID == nil,
              let card = cards.first(where: { $0.id == cardID }),
              let request = card.calendarRequest
        else {
            errorMessage = "This insight does not have enough information for a calendar event."
            return
        }

        creatingCalendarCardID = cardID
        errorMessage = nil
        actionMessage = nil

        do {
            let result = try await calendarCreator.createCalendarEvent(request)
            let updatedCard = try await cardRepository.update(card.applyingCalendarResult(result))
            replaceCard(updatedCard)
            actionMessage = "Calendar event created."
        } catch {
            errorMessage = "Unable to create calendar event."
        }

        creatingCalendarCardID = nil
    }

    func clearActionMessage() {
        actionMessage = nil
    }

    private func replaceCard(_ card: SavedInsightCard) {
        guard let index = cards.firstIndex(where: { $0.id == card.id }) else {
            cards.insert(card, at: 0)
            return
        }

        cards[index] = card
    }
}
