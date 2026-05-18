import Foundation
import Testing
@testable import CaptureFlow

struct CardResultCustomFieldTests {
    @Test func resolverTrimsPlainTextValues() {
        let resolver = CardResultCustomFieldValueResolver()

        #expect(
            resolver.resolvedValue(
                for: .note,
                textValue: "  Follow up with finance  ",
                dateValue: Date()
            ) == "Follow up with finance"
        )
        #expect(
            resolver.resolvedValue(
                for: .note,
                textValue: "   ",
                dateValue: Date()
            ) == nil
        )
    }

    @Test func resolverNormalizesLinksWithoutScheme() {
        let resolver = CardResultCustomFieldValueResolver()

        #expect(
            resolver.resolvedValue(
                for: .link,
                textValue: "example.com/path",
                dateValue: Date()
            ) == "https://example.com/path"
        )
        #expect(resolver.validationMessage(for: .link, textValue: "example.com/path") == nil)
        #expect(resolver.validationMessage(for: .link, textValue: "   ") == "Enter a link to continue.")
    }

    @Test @MainActor func viewModelBuildsCalendarRequestFromCustomDateAndTimeFields() {
        let resolver = CardResultCustomFieldValueResolver()
        let calendar = Calendar.autoupdatingCurrent
        let scheduledDate = calendar.date(
            from: DateComponents(year: 2026, month: 5, day: 15, hour: 14, minute: 30)
        )!
        let cardID = UUID()
        let viewModel = CardResultViewModel(
            card: .note(
                NoteCard(
                    metadata: CardMetadata(
                        id: cardID,
                        confidence: .medium,
                        confidenceScore: 0.72
                    ),
                    title: "Budget review",
                    summary: ""
                )
            ),
            cardRepository: InMemoryCardRepository(),
            reminderCreator: MockReminderCreator(),
            calendarCreator: MockCalendarCreator()
        )

        viewModel.addCustomField(type: .date, value: resolver.dateString(from: scheduledDate))
        viewModel.addCustomField(type: .time, value: resolver.timeString(from: scheduledDate))
        viewModel.addCustomField(type: .location, value: "  Conference Room A  ")
        viewModel.addCustomField(type: .note, value: "Bring invoices")

        let request = viewModel.calendarActionState.request
        let requestComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: request!.startDate)

        #expect(request?.sourceCardID == cardID)
        #expect(request?.title == "Budget review")
        #expect(request?.location == "Conference Room A")
        #expect(request?.notes == "Bring invoices")
        #expect(requestComponents.year == 2026)
        #expect(requestComponents.month == 5)
        #expect(requestComponents.day == 15)
        #expect(requestComponents.hour == 14)
        #expect(requestComponents.minute == 30)
        #expect(abs(request!.endDate.timeIntervalSince(request!.startDate) - 3_600) < 0.001)
    }

    @Test func savedInsightCardCopiesCreatedReminderStateFromActionCard() {
        let reminderID = "reminder-123"
        let card = ReminderCard(
            metadata: CardMetadata(
                confidence: .high,
                confidenceScore: 0.93
            ),
            title: "Follow up",
            reminderExternalID: reminderID
        )
        let insight = GeneratedInsightCard(
            title: "Follow up",
            usefulness: .useful,
            confidence: 0.93,
            summary: nil,
            sections: []
        )

        let savedCard = SavedInsightCard(
            insight: insight,
            actionCard: .reminder(card)
        )

        #expect(savedCard.reminderExternalID == reminderID)
        #expect(savedCard.effectiveReminderExternalID == reminderID)
        #expect(savedCard.reminderRequest == nil)
        #expect(savedCard.supportsReminderAction)
    }

    @Test func savedInsightCardReadsLegacyActionCardReminderState() {
        let reminderID = "legacy-reminder-123"
        let card = ShoppingCard(
            metadata: CardMetadata(
                confidence: .medium,
                confidenceScore: 0.72
            ),
            productName: "Keyboard",
            reminderExternalID: reminderID
        )
        let insight = GeneratedInsightCard(
            title: "Keyboard deal",
            usefulness: .useful,
            confidence: 0.72,
            summary: nil,
            sections: []
        )

        let savedCard = SavedInsightCard(
            metadata: CardMetadata(
                confidence: .medium,
                confidenceScore: 0.72
            ),
            insight: insight,
            actionCard: .shopping(card)
        )

        #expect(savedCard.reminderExternalID == nil)
        #expect(savedCard.effectiveReminderExternalID == reminderID)
        #expect(savedCard.reminderRequest == nil)
        #expect(savedCard.supportsReminderAction)
    }

    @Test func mockHomeSeedCardsProvideTenUniqueCards() {
        let cards = MockHomeSeedCards.cards()

        #expect(cards.count == 10)
        #expect(Set(cards.map(\.id)).count == 10)
        #expect(cards.contains { $0.effectiveReminderExternalID != nil })
        #expect(cards.contains { $0.effectiveCalendarExternalID != nil })
    }

    @Test @MainActor func detailViewModelCreatesReminderForNoteCard() async {
        let savedCard = noteSavedInsightCard()
        let repository = InMemoryCardRepository(seedCards: [savedCard])
        let viewModel = CardDetailViewModel(
            cardID: savedCard.id,
            cardRepository: repository,
            reminderCreator: MockReminderCreator(),
            calendarCreator: MockCalendarCreator()
        )

        await viewModel.load()
        viewModel.addCustomField(type: .note, value: "  Bring launch checklist  ")

        #expect(viewModel.showsReminderAction)
        #expect(viewModel.canCreateReminder)
        #expect(!viewModel.didCreateReminder)

        let updatedCard = await viewModel.createReminder()

        #expect(updatedCard?.effectiveReminderExternalID != nil)
        #expect(viewModel.didCreateReminder)
        #expect(!viewModel.canCreateReminder)
    }

    @Test @MainActor func detailViewModelShowsCreatedReminderState() async {
        let savedCard = noteSavedInsightCard(reminderExternalID: "mock-created-reminder")
        let repository = InMemoryCardRepository(seedCards: [savedCard])
        let viewModel = CardDetailViewModel(
            cardID: savedCard.id,
            cardRepository: repository,
            reminderCreator: MockReminderCreator(),
            calendarCreator: MockCalendarCreator()
        )

        await viewModel.load()

        #expect(viewModel.showsReminderAction)
        #expect(viewModel.didCreateReminder)
        #expect(!viewModel.canCreateReminder)
    }

    private func noteSavedInsightCard(reminderExternalID: String? = nil) -> SavedInsightCard {
        let metadata = CardMetadata(
            confidence: .medium,
            confidenceScore: 0.78,
            status: reminderExternalID == nil ? .saved : .completed
        )
        let insight = GeneratedInsightCard(
            id: metadata.id,
            title: "Launch notes",
            usefulness: .useful,
            confidence: 0.78,
            summary: "Captured release checklist and launch owner details.",
            sections: []
        )

        return SavedInsightCard(
            metadata: metadata,
            insight: insight,
            actionCard: .note(
                NoteCard(
                    metadata: metadata,
                    title: "Launch notes",
                    summary: "Captured release checklist and launch owner details."
                )
            ),
            reminderExternalID: reminderExternalID
        )
    }
}
