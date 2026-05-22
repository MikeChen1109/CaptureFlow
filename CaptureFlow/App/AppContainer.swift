import Foundation
import SwiftData

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
            visionAnalyzer: defaultVisionAnalyzer(),
            cardGenerator: defaultCardGenerator(),
            reminderCreator: EventKitReminderCreator(store: eventKitStore),
            calendarCreator: EventKitCalendarCreator(store: eventKitStore),
            cardRepository: defaultCardRepository()
        )
    }

    private static func defaultCardRepository() -> any CardRepository {
        do {
            let modelContainer = try ModelContainer(for: SwiftDataSavedInsightCard.self)
            return SwiftDataCardRepository(modelContainer: modelContainer)
        } catch {
            assertionFailure("Unable to initialize SwiftData card repository: \(error)")
            return InMemoryCardRepository()
        }
    }

    private static func defaultVisionAnalyzer() -> any VisionAnalyzing {
        let configuration = AIProviderConfiguration.current()

        switch configuration.provider {
        case .mock:
            return MockVisionAnalyzer()
        case .openAI:
            guard configuration.openAI.apiKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                assertionFailure("CAPTUREFLOW_AI_PROVIDER is openai but no OpenAI API key is configured.")
                return MockVisionAnalyzer()
            }

            return ProviderVisionAnalyzer(
                provider: OpenAIVisionAnalysisProvider(configuration: configuration.openAI)
            )
        }
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
