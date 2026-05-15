import Foundation

struct MockCardGenerator: CardGenerating {
    func streamGeneratedContent(
        from context: VisionUnderstandingContext
    ) -> AsyncThrowingStream<CardGenerationEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let content = GeneratedInsightCard.fallback(from: context)
                    let card = Self.placeholderCard(from: context, insight: content)

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

    static func placeholderCard(from context: VisionUnderstandingContext, insight: GeneratedInsightCard? = nil) -> ActionCard {
        let metadata = CardMetadata(
            sourceImage: context.sourceImage,
            confidence: context.confidence,
            confidenceScore: context.confidenceScore
        )

        let fallbackTitle = insight?.title.nonEmpty
            ?? context.sceneTitle.nonEmpty
            ?? context.recommendedPlanTitle.nonEmpty
            ?? "Screenshot Insight"
        let summary = insight?.summary?.nonEmpty
            ?? insight?.sections.first?.content.nonEmpty
            ?? context.sceneSummary

        switch context.resolvedCardType {
        case .auto, .note:
            return .note(
                NoteCard(
                    metadata: metadata,
                    title: fallbackTitle,
                    summary: summary
                )
            )
        case .reminder:
            return .reminder(
                ReminderCard(
                    metadata: metadata,
                    title: fallbackTitle
                )
            )
        case .calendar:
            let startDate = Date()
            return .calendar(
                CalendarCard(
                    metadata: metadata,
                    title: fallbackTitle,
                    startDate: startDate,
                    endDate: startDate.addingTimeInterval(3600)
                )
            )
        case .shopping:
            return .shopping(
                ShoppingCard(
                    metadata: metadata,
                    productName: fallbackTitle,
                    notes: summary
                )
            )
        case .job:
            return .job(
                JobCard(
                    metadata: metadata,
                    company: "Unknown company",
                    role: fallbackTitle,
                    detail: summary
                )
            )
        }
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
