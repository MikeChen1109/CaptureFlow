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

        Text cleanup rules:
        - Do not copy broken OCR fragments directly into the final card.
        - Reconstruct incomplete visibleText fragments into readable sentences when the meaning is clear from nearby context.
        - Treat text_blocks.reconstructed_text as the preferred source for text-heavy screenshots, but still rewrite it into coherent section content.
        - Do not start a bullet with connector words like "and", "or", "plus", "along with", "covering", or "rendering" unless it is clearly intentional.
        - Do not create a standalone item from a phrase that merely completes a previous item, such as "native Android" or "and Flutter development."
        - Merge fragments that belong to the same requirement, sentence, or paragraph.
        - Keep comma-separated lists together when splitting would create orphan fragments.
        - If a fragment is too incomplete to reconstruct safely, omit it or mention it in missingInfo instead of displaying it as a standalone detail.
        - Keep the final card clean and user-facing, not like raw OCR output.

        Section quality rules:
        - Each section must have a clear purpose and should summarize one meaningful theme.
        - For keyDetails and checklist sections, content must be newline-separated complete items.
        - Every content line must be understandable on its own. No line may begin with a dangling connector or lowercase continuation unless it is a proper noun.
        - Prefer 2 to 4 substantial items per section over many small fragments.
        - If several fragments form one requirement, combine them into one sentence in one item.
        - Do not use commas as item boundaries. Use newlines only between complete, independent items.
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
            "Before writing sections, mentally consolidate visible_text and text_blocks into complete semantic facts.",
            "For keyDetails/checklist content, use one complete fact per line; do not split one sentence across multiple lines.",
            "Do not produce section lines that start with dangling connectors such as 'and', 'or', 'plus', 'alongside', 'covering', or 'rendering'.",
            "Do not produce standalone continuation fragments such as 'native Android' when they belong with a previous phrase.",
            "Output detail preference: \(preferences.outputDetail.title).",
            "Output tone preference: \(preferences.outputTone.title).",
            "",
            "Required output shape:",
            "title: short, specific title based only on context.",
            "usefulness: useful, partiallyUseful, lowInformation, or unclear.",
            "confidence: 0.0 to 1.0 based on how well supported the card is by the context.",
            "summary: optional; include only when it adds value beyond the sections.",
            "sections: concise, meaningful sections using summary, keyDetails, suggestedActions, checklist, draft, missingInfo, warning, tags, or note.",
            "section.content: for keyDetails/checklist/suggestedActions, newline-separated complete items; for summary/note/warning/missingInfo, complete prose.",
            "",
            "Context:",
            "Scene title: \(context.sceneTitle)",
            "Scene summary: \(context.sceneSummary)",
            "User intent guess: \(context.userIntentGuess)",
            "Visible text:",
            context.visibleText.promptBulletLines,
            "Text blocks:",
            context.textBlocks.promptLines,
            "Visual objects:",
            context.visualObjects.promptBulletLines,
            "Layout description: \(context.layoutDescription)",
            "Entities:",
            context.entities.promptLines,
            "Possible actions:",
            context.possibleActions.promptLines,
            "Missing info:",
            context.missingInfo.promptBulletLines,
            "Constraints:",
            context.constraints.promptBulletLines,
            "Recommended plan title: \(context.recommendedPlanTitle)",
            "Evidence:",
            context.evidence.promptBulletLines,
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

private extension [String] {
    var promptBulletLines: String {
        let values = compactMap {
            let trimmed = $0.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : "- \(trimmed)"
        }

        return values.isEmpty ? "None" : values.joined(separator: "\n")
    }
}

private extension [VisionTextBlock] {
    var promptLines: String {
        guard !isEmpty else { return "None" }

        return map { block in
            let title = block.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            let displayTitle = title?.isEmpty == false ? title! : "Untitled block"

            return """
            - \(displayTitle)
              reconstructed_text: \(block.reconstructedText)
              confidence: \(block.confidence)
            """
        }
        .joined(separator: "\n")
    }
}
