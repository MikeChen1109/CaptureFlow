import Foundation

protocol CardGenerationPromptProviding: Sendable {
    func contentInstructions(for preferences: GenerationPreferences) -> String
    func contentPrompt(
        for context: VisionUnderstandingContext,
        preferences: GenerationPreferences
    ) -> String
}

struct DefaultCardGenerationPromptProvider: CardGenerationPromptProviding {
    func contentInstructions(for preferences: GenerationPreferences) -> String {
        """
        You turn screenshot analysis context into useful, concise insight cards.
        Use the provided context as the only factual source.
        Do not invent people, dates, locations, prices, companies, stores, URLs, contact details, salary, deadlines, attendees, or tasks.
        Generate only sections that are useful.
        Prefer practical next steps over generic summaries.
        Match the user's output detail preference: \(preferences.outputDetail.title).
        Match the user's output tone preference: \(preferences.outputTone.title).
        """
    }

    func contentPrompt(
        for context: VisionUnderstandingContext,
        preferences: GenerationPreferences
    ) -> String {
        var lines: [String] = [
            "Build a GeneratedInsightCard from this local image understanding context.",
            "Use the provided context as the only factual source.",
            "Generate between 1 and \(preferences.outputDetail.maximumSectionCount) sections.",
            "Do not force checklist, draft, or actions when they are not useful.",
            "If useful information is missing or uncertain, include one missingInfo section instead of guessing.",
            "Output detail preference: \(preferences.outputDetail.title).",
            "Output tone preference: \(preferences.outputTone.title).",
            "",
            "Required output shape:",
            "title: short, specific title based only on context.",
            "usefulness: useful, partiallyUseful, lowInformation, or unclear.",
            "confidence: 0.0 to 1.0 based on how well supported the card is by the context.",
            "summary: optional; include only when it adds value beyond the sections.",
            "sections: concise sections using summary, keyDetails, suggestedActions, checklist, draft, missingInfo, warning, tags, or note.",
            "",
            "Context:",
            "Scene title: \(context.sceneTitle)",
            "Scene summary: \(context.sceneSummary)",
            "User intent guess: \(context.userIntentGuess)",
            "Visible text: \(context.visibleText.promptJoinedValues)",
            "Visual objects: \(context.visualObjects.promptJoinedValues)",
            "Layout description: \(context.layoutDescription)",
            "Entities: \(context.entities.promptLines)",
            "Possible actions: \(context.possibleActions.promptLines)",
            "Missing info: \(context.missingInfo.promptJoinedValues)",
            "Constraints: \(context.constraints.promptJoinedValues)",
            "Recommended plan title: \(context.recommendedPlanTitle)",
            "Evidence: \(context.evidence.promptJoinedValues)",
            "Confidence score: \(context.confidenceScore)"
        ]

        if context.visibleText.isEmpty, context.evidence.isEmpty {
            lines.append("If the context is too thin, return lowInformation instead of inventing details.")
        }

        return lines.joined(separator: "\n")
    }
}

private extension [String] {
    var promptJoinedValues: String {
        let values = compactMap {
            let trimmed = $0.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        return values.isEmpty ? "None" : values.joined(separator: " | ")
    }
}

private extension [VisionEntity] {
    var promptLines: String {
        guard !isEmpty else {
            return "None"
        }

        return map { "\($0.type.rawValue): \($0.label)=\($0.value) confidence=\($0.confidence)" }
            .joined(separator: " | ")
    }
}

private extension [VisionActionHint] {
    var promptLines: String {
        guard !isEmpty else {
            return "None"
        }

        return map { "\($0.actionType.rawValue): \($0.title) - \($0.description)" }
            .joined(separator: " | ")
    }
}
