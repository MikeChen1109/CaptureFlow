import Foundation

struct AppContainer: Sendable {
    let visionAnalyzer: any VisionAnalyzing
    let cardGenerator: any CardGenerating
    let reminderCreator: any ReminderCreating
    let calendarCreator: any CalendarCreating
    let cardRepository: any CardRepository

    nonisolated init(
        visionAnalyzer: any VisionAnalyzing,
        cardGenerator: any CardGenerating,
        reminderCreator: any ReminderCreating,
        calendarCreator: any CalendarCreating,
        cardRepository: any CardRepository
    ) {
        self.visionAnalyzer = visionAnalyzer
        self.cardGenerator = cardGenerator
        self.reminderCreator = reminderCreator
        self.calendarCreator = calendarCreator
        self.cardRepository = cardRepository
    }

    static func local() -> AppContainer {
        let eventKitStore = EventKitActionStore()

        return AppContainer(
            visionAnalyzer: MockVisionAnalyzer(),
            cardGenerator: defaultCardGenerator(),
            reminderCreator: EventKitReminderCreator(store: eventKitStore),
            calendarCreator: EventKitCalendarCreator(store: eventKitStore),
            cardRepository: InMemoryCardRepository(seedCards: MockHomeSeedCards.cards())
        )
    }

    private static func defaultCardGenerator() -> any CardGenerating {
        if #available(iOS 26.0, *) {
            return AppleFoundationCardGenerator(
                fallbackGenerator: MockCardGenerator()
            )
        }

        return MockCardGenerator()
    }
}
