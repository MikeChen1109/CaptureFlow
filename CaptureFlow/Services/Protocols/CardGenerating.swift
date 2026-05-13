import Foundation

protocol CardGenerating: Sendable {
    func streamGeneratedContent(
        from context: VisionUnderstandingContext
    ) -> AsyncThrowingStream<CardGenerationEvent, Error>
}

enum CardGenerationEvent: Sendable {
    case partialContent(GeneratedContentPartial)
    case completed(card: ActionCard, content: GeneratedCardContent)
}

struct GeneratedContentPartial: Equatable, Sendable {
    var summary: String?
    var planTitle: String?
    var planSteps: [GeneratedPlanStep]?
    var recommendedActions: [GeneratedAction]?
    var keyDetails: [GeneratedField]?
    var missingInfo: [String]?
    var sourceReasoning: [String]?
}

extension GeneratedCardContent {
    var partialContent: GeneratedContentPartial {
        GeneratedContentPartial(
            summary: summary,
            planTitle: planTitle,
            planSteps: planSteps,
            recommendedActions: recommendedActions,
            keyDetails: keyDetails,
            missingInfo: missingInfo,
            sourceReasoning: sourceReasoning
        )
    }
}
