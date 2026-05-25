import Foundation

struct OpenAIVisionAnalyzer: VisionAnalyzing {
    private let provider: any LLMProviding
    private let model: String
    private let fallbackAnalyzer: (any VisionAnalyzing)?
    private let promptProvider: any VisionAnalysisPromptProviding

    init(
        provider: any LLMProviding,
        model: String = "gpt-4.1-mini",
        fallbackAnalyzer: (any VisionAnalyzing)? = nil,
        promptProvider: any VisionAnalysisPromptProviding = DefaultVisionAnalysisPromptProvider()
    ) {
        self.provider = provider
        self.model = model
        self.fallbackAnalyzer = fallbackAnalyzer
        self.promptProvider = promptProvider
    }

    func analyze(_ request: VisionAnalysisRequest) async throws -> VisionUnderstandingContext {
        guard let imageData = request.imageData else {
            if let fallbackAnalyzer {
                return try await fallbackAnalyzer.analyze(request)
            }

            throw ServiceError.noImageProvided
        }

        do {
            let prompt = promptProvider.prompt(
                for: VisionAnalysisPromptRequest(requestedCardType: request.selectedCardType)
            )
            let outputText = try await provider.responseText(
                for: LLMRequest(
                    model: model,
                    instructions: prompt.developerMessage,
                    input: .image(
                        data: imageData,
                        mimeType: Self.mimeType(for: imageData),
                        prompt: prompt.userMessage
                    ),
                    responseFormat: LLMResponseFormat(
                        name: VisionAnalysisResponseSchema.name,
                        schema: VisionAnalysisResponseSchema.schema
                    )
                )
            )

            guard let data = outputText.data(using: .utf8) else {
                throw ServiceError.invalidGeneratedCard
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let dto = try decoder.decode(VisionAnalysisDTO.self, from: data)
            return dto.understandingContext(from: request)
        } catch {
            if let fallbackAnalyzer {
                return try await fallbackAnalyzer.analyze(request)
            }

            throw error
        }
    }

    private static func mimeType(for data: Data) -> String {
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return "image/png"
        }

        return "image/jpeg"
    }
}
