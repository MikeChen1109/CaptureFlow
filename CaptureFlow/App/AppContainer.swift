import Foundation

struct AppContainer: Sendable {
    let visionAnalyzer: any VisionAnalyzing
    let cardGenerator: any CardGenerating
    let creditProvider: any CreditProviding
    let reminderCreator: any ReminderCreating
    let calendarCreator: any CalendarCreating
    let cardRepository: any CardRepository

    nonisolated init(
        visionAnalyzer: any VisionAnalyzing,
        cardGenerator: any CardGenerating,
        creditProvider: any CreditProviding,
        reminderCreator: any ReminderCreating,
        calendarCreator: any CalendarCreating,
        cardRepository: any CardRepository
    ) {
        self.visionAnalyzer = visionAnalyzer
        self.cardGenerator = cardGenerator
        self.creditProvider = creditProvider
        self.reminderCreator = reminderCreator
        self.calendarCreator = calendarCreator
        self.cardRepository = cardRepository
    }

    static func prototype() -> AppContainer {
        return AppContainer(
            visionAnalyzer: MockVisionAnalyzer(),
            cardGenerator: defaultCardGenerator(),
            creditProvider: MockCreditProvider(),
            reminderCreator: MockReminderCreator(),
            calendarCreator: MockCalendarCreator(),
            cardRepository: InMemoryCardRepository()
        )
    }

    private static func defaultCardGenerator() -> any CardGenerating {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return AppleFoundationCardGenerator()
        }
        #endif

        return MockCardGenerator()
    }
}
