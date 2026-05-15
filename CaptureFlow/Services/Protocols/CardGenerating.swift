import Foundation

protocol CardGenerating: Sendable {
    func streamGeneratedContent(
        from context: VisionUnderstandingContext
    ) -> AsyncThrowingStream<CardGenerationEvent, Error>
}

enum CardGenerationEvent: Sendable {
    case completed(card: ActionCard, content: GeneratedInsightCard)
}
