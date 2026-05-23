import Foundation
import Testing
@testable import CaptureFlow

@MainActor
struct CardGeneratorRouterTests {
    @Test func externalLLMUsesProvider() async throws {
        let store = makeSettingsStore()
        store.modelSelection = .externalLLM

        let router = makeRouter(
            store: store,
            provider: StubCardGenerator(title: "Provider"),
            foundation: StubCardGenerator(title: "Foundation"),
            mock: StubCardGenerator(title: "Mock"),
            isFoundationModelsAvailable: true
        )

        let content = try await completedContent(from: router)

        #expect(content.title == "Provider")
    }

    @Test func foundationModelUsesFoundationWhenAvailable() async throws {
        let store = makeSettingsStore()
        store.modelSelection = .foundationModels

        let router = makeRouter(
            store: store,
            provider: StubCardGenerator(title: "Provider"),
            foundation: StubCardGenerator(title: "Foundation"),
            mock: StubCardGenerator(title: "Mock"),
            isFoundationModelsAvailable: true
        )

        let content = try await completedContent(from: router)

        #expect(content.title == "Foundation")
    }

    @Test func foundationModelFallsBackToProviderWhenFoundationIsUnavailable() async throws {
        let store = makeSettingsStore()
        store.modelSelection = .foundationModels

        let router = makeRouter(
            store: store,
            provider: StubCardGenerator(title: "Provider"),
            foundation: nil,
            mock: StubCardGenerator(title: "Mock"),
            isFoundationModelsAvailable: false
        )

        let content = try await completedContent(from: router)

        #expect(content.title == "Provider")
    }

    @Test func providerErrorMapperHidesRejectedKeyDetails() throws {
        let error = ProviderErrorMapper.error(
            statusCode: 401,
            data: Data(#"{"error":{"message":"raw provider auth detail"}}"#.utf8)
        )

        #expect((error as? ServiceError) == .unavailable("The provider key was rejected. Check the saved API key."))
    }

    @Test func providerErrorMapperUsesSafeProviderMessageForValidationErrors() throws {
        let error = ProviderErrorMapper.error(
            statusCode: 400,
            data: Data(#"{"error":{"message":"Unsupported model."}}"#.utf8)
        )

        #expect((error as? ServiceError) == .unavailable("Unsupported model."))
    }

    @Test func aiProviderConfigurationProvidesOpenAIKeyForGeneration() throws {
        let configuration = AIProviderConfiguration.current(
            environment: [
                "CAPTUREFLOW_AI_PROVIDER": "openai",
                "CAPTUREFLOW_OPENAI_API_KEY": " test-api-key "
            ]
        )

        #expect(configuration.provider == .openAI)
        #expect(try configuration.apiKey(for: .openAI) == "test-api-key")
    }

    private func makeRouter(
        store: GenerationProviderSettingsStore,
        provider: any CardGenerating,
        foundation: (any CardGenerating)?,
        mock: any CardGenerating,
        isFoundationModelsAvailable: Bool
    ) -> CardGeneratorRouter {
        CardGeneratorRouter(
            settingsStore: store,
            providerGenerator: provider,
            foundationGenerator: foundation,
            mockGenerator: mock,
            isFoundationModelsAvailable: { isFoundationModelsAvailable }
        )
    }

    private func makeSettingsStore() -> GenerationProviderSettingsStore {
        let suiteName = "CaptureFlowTests.CardGeneratorRouter.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)

        return GenerationProviderSettingsStore(userDefaults: userDefaults)
    }

    private func completedContent(
        from generator: any CardGenerating
    ) async throws -> GeneratedInsightCard {
        for try await event in generator.streamGeneratedContent(from: Self.context) {
            if case .completed(_, let content) = event {
                return content
            }
        }

        throw ServiceError.invalidGeneratedCard
    }

    private static let context = VisionUnderstandingContext(
        requestedCardType: .note,
        resolvedCardType: .note,
        sceneTitle: "Receipt",
        sceneSummary: "A receipt with a total.",
        userIntentGuess: "Save expense",
        visibleText: ["Total $12.00"],
        layoutDescription: "Receipt details",
        recommendedPlanTitle: "Save receipt",
        confidenceScore: 0.9
    )
}

private struct StubCardGenerator: CardGenerating {
    let title: String

    func streamGeneratedContent(
        from context: VisionUnderstandingContext
    ) -> AsyncThrowingStream<CardGenerationEvent, Error> {
        AsyncThrowingStream { continuation in
            let content = GeneratedInsightCard(
                title: title,
                usefulness: .useful,
                confidence: 0.9,
                summary: "\(title) summary",
                sections: [
                    InsightSection(
                        kind: .summary,
                        title: "\(title) section",
                        content: "\(title) content",
                        priority: 1
                    )
                ]
            )
            let card = MockCardGenerator.placeholderCard(from: context, insight: content)

            continuation.yield(.completed(card: card, content: content))
            continuation.finish()
        }
    }
}
