import Foundation
import SwiftData

struct AppContainer: Sendable {
    let visionAnalyzer: any VisionAnalyzing
    let cardGenerator: any CardGenerating
    let reminderCreator: any ReminderCreating
    let calendarCreator: any CalendarCreating
    let cardRepository: any CardRepository
    let providerSettingsStore: GenerationProviderSettingsStore
    let llmConfiguration: LLMProviderConfiguration

    nonisolated init(
        visionAnalyzer: any VisionAnalyzing,
        cardGenerator: any CardGenerating,
        reminderCreator: any ReminderCreating,
        calendarCreator: any CalendarCreating,
        cardRepository: any CardRepository,
        providerSettingsStore: GenerationProviderSettingsStore,
        llmConfiguration: LLMProviderConfiguration = .openAIDefault
    ) {
        self.visionAnalyzer = visionAnalyzer
        self.cardGenerator = cardGenerator
        self.reminderCreator = reminderCreator
        self.calendarCreator = calendarCreator
        self.cardRepository = cardRepository
        self.providerSettingsStore = providerSettingsStore
        self.llmConfiguration = llmConfiguration
    }

    static func local(
        aiProviderConfiguration: AIProviderConfiguration = .current(),
        credentialProvider: (any LLMProviderCredentialProviding)? = nil,
        llmConfiguration: LLMProviderConfiguration = .openAIDefault,
        visionPromptProvider: any VisionAnalysisPromptProviding = DefaultVisionAnalysisPromptProvider(),
        promptProvider: any CardGenerationPromptProviding = DefaultCardGenerationPromptProvider()
    ) -> AppContainer {
        let eventKitStore = EventKitActionStore()
        let providerSettingsStore = GenerationProviderSettingsStore.shared
        let credentialProvider = credentialProvider ?? aiProviderConfiguration
        let openAIProvider = OpenAIResponsesLLMProvider(
            credentialProvider: credentialProvider,
            endpoint: aiProviderConfiguration.openAI.responsesURL
        )

        return AppContainer(
            visionAnalyzer: defaultVisionAnalyzer(
                configuration: aiProviderConfiguration,
                promptProvider: visionPromptProvider
            ),
            cardGenerator: defaultCardGenerator(
                providerSettingsStore: providerSettingsStore,
                externalLLMProvider: openAIProvider,
                llmConfiguration: llmConfiguration,
                promptProvider: promptProvider
            ),
            reminderCreator: EventKitReminderCreator(store: eventKitStore),
            calendarCreator: EventKitCalendarCreator(store: eventKitStore),
            cardRepository: defaultCardRepository(),
            providerSettingsStore: providerSettingsStore,
            llmConfiguration: llmConfiguration
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

    private static func defaultVisionAnalyzer(
        configuration: AIProviderConfiguration,
        promptProvider: any VisionAnalysisPromptProviding
    ) -> any VisionAnalyzing {
        switch configuration.provider {
        case .mock:
            return MockVisionAnalyzer()
        case .openAI:
            guard configuration.openAI.apiKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                assertionFailure("CAPTUREFLOW_AI_PROVIDER is openai but no OpenAI API key is configured.")
                return MockVisionAnalyzer()
            }

            return ProviderVisionAnalyzer(
                provider: OpenAIVisionAnalysisProvider(
                    configuration: configuration.openAI,
                    promptProvider: promptProvider
                )
            )
        }
    }

    private static func defaultCardGenerator(
        providerSettingsStore: GenerationProviderSettingsStore,
        externalLLMProvider: any LLMProviding,
        llmConfiguration: LLMProviderConfiguration,
        promptProvider: any CardGenerationPromptProviding
    ) -> any CardGenerating {
        let providerGenerator = OpenAIResponsesCardGenerator(
            provider: externalLLMProvider,
            model: llmConfiguration.generationModel,
            promptProvider: promptProvider
        )
        let mockGenerator = MockCardGenerator()

        return CardGeneratorRouter(
            settingsStore: providerSettingsStore,
            providerGenerator: providerGenerator,
            foundationGenerator: defaultFoundationCardGenerator(
                fallbackGenerator: providerGenerator,
                promptProvider: promptProvider
            ),
            mockGenerator: mockGenerator
        )
    }

    private static func defaultFoundationCardGenerator(
        fallbackGenerator: any CardGenerating,
        promptProvider: any CardGenerationPromptProviding
    ) -> (any CardGenerating)? {
        if #available(iOS 26.0, *) {
            return AppleFoundationCardGenerator(
                promptProvider: promptProvider,
                fallbackGenerator: fallbackGenerator
            )
        }

        return nil
    }
}
