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

    @Test func openAIDefaultUsesFullGenerationModel() {
        #expect(LLMProviderConfiguration.openAIDefault.generationModel == "gpt-4.1")
    }

    @Test func openAIGeneratorMergesContinuationFragments() async throws {
        let generator = OpenAIResponsesCardGenerator(
            provider: StubLLMProvider(
                response: """
                {
                  "title": "Mobile Developer Role",
                  "usefulness": "useful",
                  "confidence": 0.9,
                  "summary": "A mobile developer role with visible requirements.",
                  "sections": [
                    {
                      "kind": "keyDetails",
                      "title": "Core Mobile Development Skills",
                      "content": "Candidates must have 5+ years of mobile development experience with native iOS\\nnative Android\\nand Flutter development.\\nExperience building intuitive\\nuser-centric applications is required.",
                      "priority": 1
                    }
                  ]
                }
                """
            )
        )

        let content = try await completedContent(from: generator)

        #expect(
            content.sections.first?.content ==
                """
                Candidates must have 5+ years of mobile development experience with native iOS, native Android and Flutter development.
                Experience building intuitive, user-centric applications is required.
                """
        )
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
        #expect(configuration.openAI.visionModel == LLMProviderConfiguration.openAIDefault.visionModel)
        #expect(configuration.openAI.promptID == nil)
    }

    @Test func aiProviderConfigurationSupportsCustomOpenAIPromptID() throws {
        let configuration = AIProviderConfiguration.current(
            environment: [
                "CAPTUREFLOW_AI_PROVIDER": "openai",
                "CAPTUREFLOW_OPENAI_API_KEY": "test-api-key",
                "CAPTUREFLOW_OPENAI_PROMPT_ID": "pmpt_custom",
                "CAPTUREFLOW_OPENAI_PROMPT_VERSION": "7",
                "CAPTUREFLOW_OPENAI_VISION_MODEL": "gpt-custom-vision"
            ]
        )

        #expect(configuration.openAI.visionModel == "gpt-custom-vision")
        #expect(configuration.openAI.promptID == "pmpt_custom")
        #expect(configuration.openAI.promptVersion == "7")
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

private struct StubLLMProvider: LLMProviding {
    let response: String

    func responseText(for request: LLMRequest) async throws -> String {
        response
    }
}
