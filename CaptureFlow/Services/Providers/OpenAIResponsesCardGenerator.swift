import Foundation

struct OpenAIResponsesCardGenerator: CardGenerating {
    private let provider: any LLMProviding
    private let model: String
    private let promptProvider: any CardGenerationPromptProviding

    init(
        provider: any LLMProviding,
        model: String = LLMProviderConfiguration.openAIDefault.generationModel,
        promptProvider: any CardGenerationPromptProviding = DefaultCardGenerationPromptProvider()
    ) {
        self.provider = provider
        self.model = model
        self.promptProvider = promptProvider
    }

    func streamGeneratedContent(
        from context: VisionUnderstandingContext
    ) -> AsyncThrowingStream<CardGenerationEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let content = try await generateContent(from: context)
                    let card = GeneratedActionCardFactory.makeActionCard(from: content, context: context)

                    continuation.yield(.completed(card: card, content: content))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func generateContent(from context: VisionUnderstandingContext) async throws -> GeneratedInsightCard {
        let preferences = GenerationPreferences.current()
        let outputText = try await provider.responseText(
            for: LLMRequest(
                model: model,
                instructions: promptProvider.contentInstructions(for: preferences),
                input: .text(promptProvider.contentPrompt(for: context, preferences: preferences)),
                responseFormat: LLMResponseFormat(
                    name: "capture_flow_generated_insight_card",
                    schema: Self.responseSchema
                )
            )
        )
        guard let jsonData = outputText.data(using: .utf8) else {
            throw ServiceError.invalidGeneratedCard
        }
        return try JSONDecoder().decode(ProviderGeneratedInsightCard.self, from: jsonData)
            .insightCard(preferences: preferences)
    }

    private static let responseSchema: [String: Sendable] = [
        "type": "object",
        "additionalProperties": false,
        "required": ["title", "usefulness", "confidence", "summary", "sections"],
        "properties": [
            "title": ["type": "string"],
            "usefulness": [
                "type": "string",
                "enum": ["useful", "partiallyUseful", "lowInformation", "unclear"]
            ],
            "confidence": ["type": "number", "minimum": 0, "maximum": 1],
            "summary": ["type": ["string", "null"]],
            "sections": [
                "type": "array",
                "minItems": 1,
                "maxItems": 7,
                "items": [
                    "type": "object",
                    "additionalProperties": false,
                    "required": ["kind", "title", "content", "priority"],
                    "properties": [
                        "kind": [
                            "type": "string",
                            "enum": [
                                "summary",
                                "keyDetails",
                                "suggestedActions",
                                "checklist",
                                "draft",
                                "missingInfo",
                                "warning",
                                "tags",
                                "note"
                            ]
                        ],
                        "title": ["type": "string"],
                        "content": ["type": "string"],
                        "priority": ["type": "integer", "minimum": 1]
                    ]
                ]
            ]
        ]
    ]
}

private struct ProviderGeneratedInsightCard: Decodable {
    var title: String
    var usefulness: InsightUsefulness
    var confidence: Double
    var summary: String?
    var sections: [ProviderInsightSection]

    func insightCard(preferences: GenerationPreferences) throws -> GeneratedInsightCard {
        let mappedSections = sections
            .sorted { $0.priority < $1.priority }
            .prefix(preferences.outputDetail.maximumSectionCount)
            .map {
                InsightSection(
                    kind: $0.kind,
                    title: $0.title,
                    content: $0.content,
                    priority: $0.priority
                )
            }

        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !mappedSections.isEmpty
        else {
            throw ServiceError.invalidGeneratedCard
        }

        return GeneratedInsightCard(
            title: title,
            usefulness: usefulness,
            confidence: min(max(confidence, 0), 1),
            summary: summary,
            sections: Array(mappedSections)
        )
    }
}

private struct ProviderInsightSection: Decodable {
    var kind: InsightSectionKind
    var title: String
    var content: String
    var priority: Int
}
