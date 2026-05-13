import Foundation

struct MockCardGenerator: CardGenerating {
    func streamGeneratedContent(
        from context: VisionUnderstandingContext
    ) -> AsyncThrowingStream<CardGenerationEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let content = GeneratedCardContent.fallback(from: context)
                    let card = Self.placeholderCard(from: context)

                    for partial in Self.partials(from: content) {
                        continuation.yield(.partialContent(partial))
                        try await Task.sleep(for: .milliseconds(120))
                    }

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

    static func placeholderCard(from context: VisionUnderstandingContext) -> ActionCard {
        let metadata = CardMetadata(
            sourceImage: context.sourceImage,
            confidence: context.confidence,
            confidenceScore: context.confidenceScore
        )

        let fallbackTitle = context.sceneTitle
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
            ? context.recommendedPlanTitle
            : context.sceneTitle

        switch context.resolvedCardType {
        case .auto, .note:
            return .note(
                NoteCard(
                    metadata: metadata,
                    title: fallbackTitle.isEmpty ? "Generated Note" : fallbackTitle,
                    summary: context.sceneSummary
                )
            )
        case .reminder:
            return .reminder(
                ReminderCard(
                    metadata: metadata,
                    title: fallbackTitle.isEmpty ? "Generated Reminder" : fallbackTitle
                )
            )
        case .calendar:
            let startDate = Date()
            return .calendar(
                CalendarCard(
                    metadata: metadata,
                    title: fallbackTitle.isEmpty ? "Generated Event" : fallbackTitle,
                    startDate: startDate,
                    endDate: startDate.addingTimeInterval(3600)
                )
            )
        case .shopping:
            return .shopping(
                ShoppingCard(
                    metadata: metadata,
                    productName: fallbackTitle.isEmpty ? "Generated Item" : fallbackTitle
                )
            )
        case .job:
            return .job(
                JobCard(
                    metadata: metadata,
                    company: "Unknown company",
                    role: fallbackTitle.isEmpty ? "Generated Job" : fallbackTitle,
                    detail: ""
                )
            )
        }
    }

    private static func partials(from content: GeneratedCardContent) -> [GeneratedContentPartial] {
        let summaryTokens = content.summary.split(separator: " ")
        let firstSummaryChunk = summaryTokens.prefix(8).joined(separator: " ")

        return [
            GeneratedContentPartial(summary: firstSummaryChunk),
            GeneratedContentPartial(summary: content.summary),
            GeneratedContentPartial(planTitle: content.planTitle, planSteps: content.planSteps),
            GeneratedContentPartial(keyDetails: content.keyDetails),
            GeneratedContentPartial(missingInfo: content.missingInfo),
            GeneratedContentPartial(sourceReasoning: content.sourceReasoning)
        ]
    }
}
