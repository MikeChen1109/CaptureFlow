import Foundation

struct OpenAIVisionAnalyzer: VisionAnalyzing {
    private let provider: any LLMProviding
    private let model: String
    private let fallbackAnalyzer: (any VisionAnalyzing)?

    init(
        provider: any LLMProviding,
        model: String = "gpt-4.1-mini",
        fallbackAnalyzer: (any VisionAnalyzing)? = nil
    ) {
        self.provider = provider
        self.model = model
        self.fallbackAnalyzer = fallbackAnalyzer
    }

    func analyze(_ request: VisionAnalysisRequest) async throws -> VisionUnderstandingContext {
        guard let imageData = request.imageData else {
            if let fallbackAnalyzer {
                return try await fallbackAnalyzer.analyze(request)
            }

            throw ServiceError.noImageProvided
        }

        do {
            let outputText = try await provider.responseText(
                for: LLMRequest(
                    model: model,
                    instructions: Self.instructions,
                    input: .image(
                        data: imageData,
                        mimeType: Self.mimeType(for: imageData),
                        prompt: Self.prompt(for: request)
                    ),
                    responseFormat: LLMResponseFormat(
                        name: "capture_flow_vision_context",
                        schema: Self.responseSchema
                    )
                )
            )

            guard let data = outputText.data(using: .utf8) else {
                throw ServiceError.invalidGeneratedCard
            }

            let content = try JSONDecoder().decode(ProviderVisionUnderstandingContext.self, from: data)
            return content.context(
                requestedCardType: request.selectedCardType,
                sourceImage: request.sourceImage
            )
        } catch {
            if let fallbackAnalyzer {
                return try await fallbackAnalyzer.analyze(request)
            }

            throw error
        }
    }

    private static let instructions = """
    You extract structured visual understanding from a screenshot or captured image.
    Use only visible evidence from the image.
    Do not invent people, dates, locations, prices, companies, stores, URLs, contact details, salary, deadlines, attendees, or tasks.
    If a detail is uncertain or missing, put it in missingInfo or constraints instead of guessing.
    Choose the resolved card type that best fits the image and the user's selected card type.
    """

    private static func prompt(for request: VisionAnalysisRequest) -> String {
        """
        Analyze this image for CaptureFlow.
        Requested card type: \(request.selectedCardType.rawValue)

        Return concise structured context for a downstream insight-card generator.
        Include evidence for important extracted facts.
        """
    }

    private static func mimeType(for data: Data) -> String {
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return "image/png"
        }

        return "image/jpeg"
    }

    private static let responseSchema: [String: Sendable] = [
        "type": "object",
        "additionalProperties": false,
        "required": [
            "resolvedCardType",
            "sceneTitle",
            "sceneSummary",
            "userIntentGuess",
            "visibleText",
            "visualObjects",
            "layoutDescription",
            "entities",
            "possibleActions",
            "constraints",
            "missingInfo",
            "recommendedPlanTitle",
            "confidenceScore",
            "evidence"
        ],
        "properties": [
            "resolvedCardType": [
                "type": "string",
                "enum": CardType.allCases.map(\.rawValue)
            ],
            "sceneTitle": ["type": "string"],
            "sceneSummary": ["type": "string"],
            "userIntentGuess": ["type": "string"],
            "visibleText": [
                "type": "array",
                "items": ["type": "string"]
            ],
            "visualObjects": [
                "type": "array",
                "items": ["type": "string"]
            ],
            "layoutDescription": ["type": "string"],
            "entities": [
                "type": "array",
                "items": [
                    "type": "object",
                    "additionalProperties": false,
                    "required": ["type", "label", "value", "confidence"],
                    "properties": [
                        "type": [
                            "type": "string",
                            "enum": VisionEntityType.allCases.map(\.rawValue)
                        ],
                        "label": ["type": "string"],
                        "value": ["type": "string"],
                        "confidence": ["type": "number", "minimum": 0, "maximum": 1]
                    ]
                ]
            ],
            "possibleActions": [
                "type": "array",
                "items": [
                    "type": "object",
                    "additionalProperties": false,
                    "required": ["title", "description", "actionType"],
                    "properties": [
                        "title": ["type": "string"],
                        "description": ["type": "string"],
                        "actionType": [
                            "type": "string",
                            "enum": VisionActionType.allCases.map(\.rawValue)
                        ]
                    ]
                ]
            ],
            "constraints": [
                "type": "array",
                "items": ["type": "string"]
            ],
            "missingInfo": [
                "type": "array",
                "items": ["type": "string"]
            ],
            "recommendedPlanTitle": ["type": "string"],
            "confidenceScore": ["type": "number", "minimum": 0, "maximum": 1],
            "evidence": [
                "type": "array",
                "items": ["type": "string"]
            ]
        ]
    ]
}

private struct ProviderVisionUnderstandingContext: Decodable {
    var resolvedCardType: CardType
    var sceneTitle: String
    var sceneSummary: String
    var userIntentGuess: String
    var visibleText: [String]
    var visualObjects: [String]
    var layoutDescription: String
    var entities: [ProviderVisionEntity]
    var possibleActions: [ProviderVisionActionHint]
    var constraints: [String]
    var missingInfo: [String]
    var recommendedPlanTitle: String
    var confidenceScore: Double
    var evidence: [String]

    func context(
        requestedCardType: CardType,
        sourceImage: CardSourceImage?
    ) -> VisionUnderstandingContext {
        VisionUnderstandingContext(
            requestedCardType: requestedCardType,
            resolvedCardType: resolvedCardType,
            sourceImage: sourceImage,
            sceneTitle: sceneTitle,
            sceneSummary: sceneSummary,
            userIntentGuess: userIntentGuess,
            visibleText: visibleText,
            visualObjects: visualObjects,
            layoutDescription: layoutDescription,
            entities: entities.map(\.entity),
            possibleActions: possibleActions.map(\.actionHint),
            constraints: constraints,
            missingInfo: missingInfo,
            recommendedPlanTitle: recommendedPlanTitle,
            confidenceScore: min(max(confidenceScore, 0), 1),
            evidence: evidence
        )
    }
}

private struct ProviderVisionEntity: Decodable {
    var type: VisionEntityType
    var label: String
    var value: String
    var confidence: Double

    var entity: VisionEntity {
        VisionEntity(
            type: type,
            label: label,
            value: value,
            confidence: min(max(confidence, 0), 1)
        )
    }
}

private struct ProviderVisionActionHint: Decodable {
    var title: String
    var description: String
    var actionType: VisionActionType

    var actionHint: VisionActionHint {
        VisionActionHint(
            title: title,
            description: description,
            actionType: actionType
        )
    }
}
