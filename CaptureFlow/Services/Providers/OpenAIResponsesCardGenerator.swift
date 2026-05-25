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
            "title": [
                "type": "string",
                "description": "Short, specific title based only on visible context."
            ],
            "usefulness": [
                "type": "string",
                "enum": ["useful", "partiallyUseful", "lowInformation", "unclear"]
            ],
            "confidence": ["type": "number", "minimum": 0, "maximum": 1],
            "summary": [
                "type": ["string", "null"],
                "description": "Optional complete prose summary. Do not include raw OCR fragments."
            ],
            "sections": [
                "type": "array",
                "description": "Meaningful card sections. Prefer fewer coherent sections over many small fragment sections.",
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
                        "title": [
                            "type": "string",
                            "description": "Human-readable section title describing one meaningful theme."
                        ],
                        "content": [
                            "type": "string",
                            "description": "User-facing cleaned content. For keyDetails, checklist, and suggestedActions, use newline-separated complete items only. Each line must be understandable alone; do not include orphan fragments, dangling connector starts, raw OCR line breaks, or comma-split pieces of one sentence."
                        ],
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
                    content: $0.cleanedContent,
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

    var cleanedContent: String {
        switch kind {
        case .keyDetails, .checklist, .suggestedActions:
            content.mergingContinuationLines
        default:
            content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

private extension String {
    var mergingContinuationLines: String {
        let lines = split(whereSeparator: \.isNewline)
            .map { String($0).strippingListPrefix.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var merged: [String] = []
        for line in lines {
            guard line.isContinuationFragment, let previous = merged.popLast() else {
                merged.append(line)
                continue
            }

            merged.append(previous.mergingContinuation(line))
        }

        return merged.joined(separator: "\n")
    }

    var strippingListPrefix: String {
        var value = trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["- [ ] ", "- ", "* ", "• "] where value.hasPrefix(prefix) {
            value.removeFirst(prefix.count)
            return value
        }
        return value
    }

    var isContinuationFragment: Bool {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = value.first else {
            return false
        }

        let lowered = value.lowercased()
        if ["and ", "or ", "plus ", "alongside ", "along with ", "covering ", "rendering "]
            .contains(where: { lowered.hasPrefix($0) }) {
            return true
        }

        return first.isLowercase
    }

    func mergingContinuation(_ continuation: String) -> String {
        let trimmedContinuation = continuation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContinuation.isEmpty else {
            return self
        }

        if trimmedContinuation.lowercased().hasPrefix("and ") {
            return "\(self) \(trimmedContinuation)"
        }

        return "\(self), \(trimmedContinuation)"
    }
}
