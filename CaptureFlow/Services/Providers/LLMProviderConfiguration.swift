import Foundation

struct LLMProviderConfiguration: Sendable {
    var displayName: String
    var visionModel: String
    var generationModel: String

    init(
        displayName: String = "OpenAI",
        visionModel: String = "gpt-4.1-mini",
        generationModel: String = "gpt-4.1-mini"
    ) {
        self.displayName = displayName
        self.visionModel = visionModel
        self.generationModel = generationModel
    }

    nonisolated static let openAIDefault = LLMProviderConfiguration()
}
