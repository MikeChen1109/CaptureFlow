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
}
