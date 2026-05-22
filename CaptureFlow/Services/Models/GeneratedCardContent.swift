import Foundation

enum InsightUsefulness: String, nonisolated Codable, nonisolated Hashable, CaseIterable, Sendable {
    case useful
    case partiallyUseful
    case lowInformation
    case unclear
}

struct GeneratedInsightCard: nonisolated Codable, nonisolated Hashable, Identifiable, Sendable {
    var id: UUID
    var title: String
    var usefulness: InsightUsefulness
    var confidence: Double
    var summary: String?
    var sections: [InsightSection]

    nonisolated init(
        id: UUID = UUID(),
        title: String,
        usefulness: InsightUsefulness,
        confidence: Double,
        summary: String?,
        sections: [InsightSection]
    ) {
        self.id = id
        self.title = title
        self.usefulness = usefulness
        self.confidence = confidence
        self.summary = summary
        self.sections = sections
    }
}

struct InsightSection: nonisolated Codable, nonisolated Hashable, Identifiable, Sendable {
    var id: UUID
    var kind: InsightSectionKind
    var title: String
    var content: String
    var priority: Int

    nonisolated init(
        id: UUID = UUID(),
        kind: InsightSectionKind,
        title: String,
        content: String,
        priority: Int
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.content = content
        self.priority = priority
    }
}

enum InsightSectionKind: String, nonisolated Codable, nonisolated Hashable, CaseIterable, Sendable {
    case summary
    case keyDetails
    case suggestedActions
    case checklist
    case draft
    case missingInfo
    case warning
    case tags
    case note
}

extension GeneratedInsightCard {
    nonisolated static func fallback(from context: VisionUnderstandingContext) -> GeneratedInsightCard {
        let cleanedSummary = context.sceneSummary.trimmedNonEmpty
        let keyDetails = context.entities
            .map { "\($0.label): \($0.value)" }
            .joinedNonEmpty(separator: "\n")
        let suggestedActions = context.possibleActions
            .map { "\($0.title): \($0.description)" }
            .joinedNonEmpty(separator: "\n")
        let missingInfo = context.generatedMissingInfo.joinedNonEmpty(separator: "\n")

        var sections: [InsightSection] = []

        if let keyDetails {
            sections.append(
                InsightSection(
                    kind: .keyDetails,
                    title: "Key Details",
                    content: keyDetails,
                    priority: 1
                )
            )
        }

        if let suggestedActions {
            sections.append(
                InsightSection(
                    kind: .suggestedActions,
                    title: "Suggested Actions",
                    content: suggestedActions,
                    priority: 2
                )
            )
        }

        if let missingInfo {
            sections.append(
                InsightSection(
                    kind: .missingInfo,
                    title: "Missing Information",
                    content: missingInfo,
                    priority: 3
                )
            )
        }

        if sections.isEmpty, let cleanedSummary {
            sections.append(
                InsightSection(
                    kind: .summary,
                    title: "What Is Visible",
                    content: cleanedSummary,
                    priority: 1
                )
            )
        }

        let usefulness = Self.usefulness(for: context, sections: sections)
        if sections.isEmpty {
            sections.append(
                InsightSection(
                    kind: usefulness == .unclear ? .missingInfo : .note,
                    title: usefulness == .unclear ? "Needs Context" : "Low Information",
                    content: usefulness == .unclear
                        ? "The screenshot context is not clear enough to infer what the card should help with."
                        : "The screenshot does not contain enough clear information to generate a useful card.",
                    priority: 1
                )
            )
        }

        return GeneratedInsightCard(
            title: context.sceneTitle.trimmedNonEmpty
                ?? context.recommendedPlanTitle.trimmedNonEmpty
                ?? "Screenshot Insight",
            usefulness: usefulness,
            confidence: context.confidenceScore.clamped(to: 0...1),
            summary: cleanedSummary,
            sections: Array(sections.sorted { $0.priority < $1.priority }.prefix(5))
        )
    }

    nonisolated var markdown: String {
        var lines = ["# \(title.trimmedForMarkdown)"]
        lines.append("- **Usefulness:** \(usefulness.displayName)")
        lines.append("- **Confidence:** \(Int((confidence.clamped(to: 0...1) * 100).rounded()))%")

        if let summary = summary?.trimmedForMarkdown, !summary.isEmpty {
            lines.append("")
            lines.append("## Summary")
            lines.append(summary)
        }

        for section in sections.sorted(by: { $0.priority < $1.priority }) {
            let title = section.title.trimmedForMarkdown
            let content = section.content.trimmedForMarkdown
            guard !title.isEmpty, !content.isEmpty else {
                continue
            }

            lines.append("")
            lines.append("## \(title)")
            lines.append(content)
        }

        return lines.joined(separator: "\n")
    }

    private nonisolated static func usefulness(
        for context: VisionUnderstandingContext,
        sections: [InsightSection]
    ) -> InsightUsefulness {
        let hasFacts = !context.entities.isEmpty || !context.visibleText.isEmpty || context.sceneSummary.trimmedNonEmpty != nil
        let hasActions = !context.possibleActions.isEmpty

        if context.confidenceScore < 0.35 || !hasFacts {
            return context.userIntentGuess.trimmedNonEmpty == nil ? .unclear : .lowInformation
        }

        if sections.count <= 1, !hasActions {
            return .partiallyUseful
        }

        return .useful
    }
}

extension VisionUnderstandingContext {
    nonisolated var generatedMissingInfo: [String] {
        (missingInfo + constraints.filter { $0.localizedCaseInsensitiveContains("not visible") })
            .uniqueCaseInsensitive()
    }
}

private extension InsightUsefulness {
    nonisolated var displayName: String {
        switch self {
        case .useful:
            "Useful"
        case .partiallyUseful:
            "Partially useful"
        case .lowInformation:
            "Low information"
        case .unclear:
            "Unclear"
        }
    }
}

private extension String {
    nonisolated var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    nonisolated var trimmedForMarkdown: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension [String] {
    nonisolated func joinedNonEmpty(separator: String) -> String? {
        let values = compactMap(\.trimmedNonEmpty)
        return values.isEmpty ? nil : values.joined(separator: separator)
    }

    nonisolated func uniqueCaseInsensitive() -> [String] {
        reduce(into: []) { result, value in
            guard !result.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) else {
                return
            }

            result.append(value)
        }
    }
}

private extension Double {
    nonisolated func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
