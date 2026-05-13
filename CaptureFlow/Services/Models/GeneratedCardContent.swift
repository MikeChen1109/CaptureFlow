import Foundation

struct GeneratedCardContent: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var summary: String
    var planTitle: String
    var planSteps: [GeneratedPlanStep]
    var keyDetails: [GeneratedField]
    var recommendedActions: [GeneratedAction]
    var missingInfo: [String]
    var sourceReasoning: [String]
    var personalNotePlaceholder: String

    nonisolated init(
        id: UUID = UUID(),
        summary: String,
        planTitle: String,
        planSteps: [GeneratedPlanStep],
        keyDetails: [GeneratedField],
        recommendedActions: [GeneratedAction],
        missingInfo: [String],
        sourceReasoning: [String],
        personalNotePlaceholder: String = "Add your own note..."
    ) {
        self.id = id
        self.summary = summary
        self.planTitle = planTitle
        self.planSteps = planSteps
        self.keyDetails = keyDetails
        self.recommendedActions = recommendedActions
        self.missingInfo = missingInfo
        self.sourceReasoning = sourceReasoning
        self.personalNotePlaceholder = personalNotePlaceholder
    }
}

struct GeneratedPlanStep: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var title: String
    var detail: String
    var actionType: VisionActionType

    nonisolated init(
        id: UUID = UUID(),
        title: String,
        detail: String,
        actionType: VisionActionType
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.actionType = actionType
    }
}

struct GeneratedField: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var label: String
    var value: String
    var type: VisionEntityType
    var confidence: Double

    nonisolated init(
        id: UUID = UUID(),
        label: String,
        value: String,
        type: VisionEntityType,
        confidence: Double
    ) {
        self.id = id
        self.label = label
        self.value = value
        self.type = type
        self.confidence = confidence
    }
}

struct GeneratedAction: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var title: String
    var description: String
    var actionType: VisionActionType

    nonisolated init(
        id: UUID = UUID(),
        title: String,
        description: String,
        actionType: VisionActionType
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.actionType = actionType
    }
}

extension GeneratedCardContent {
    nonisolated static func fallback(from context: VisionUnderstandingContext) -> GeneratedCardContent {
        GeneratedCardContent(
            summary: context.sceneSummary,
            planTitle: context.recommendedPlanTitle,
            planSteps: context.generatedPlanSteps,
            keyDetails: context.generatedKeyDetails,
            recommendedActions: context.generatedRecommendedActions,
            missingInfo: context.generatedMissingInfo,
            sourceReasoning: context.evidence,
            personalNotePlaceholder: "Add your own note..."
        )
    }
}

extension VisionUnderstandingContext {
    nonisolated var generatedPlanSteps: [GeneratedPlanStep] {
        let steps = possibleActions.map {
            GeneratedPlanStep(
                title: $0.title,
                detail: $0.description,
                actionType: $0.actionType
            )
        }

        guard !steps.isEmpty else {
            let fallbackDetail = sceneSummary.trimmingCharacters(in: .whitespacesAndNewlines)
            return [
                GeneratedPlanStep(
                    title: recommendedPlanTitle,
                    detail: fallbackDetail.isEmpty ? "Review captured details and decide next steps." : fallbackDetail,
                    actionType: .save
                )
            ]
        }

        return steps
    }

    nonisolated var generatedKeyDetails: [GeneratedField] {
        entities.map {
            GeneratedField(
                label: $0.label,
                value: $0.value,
                type: $0.type,
                confidence: $0.confidence
            )
        }
    }

    nonisolated var generatedRecommendedActions: [GeneratedAction] {
        possibleActions.map {
            GeneratedAction(
                title: $0.title,
                description: $0.description,
                actionType: $0.actionType
            )
        }
    }

    nonisolated var generatedMissingInfo: [String] {
        (missingInfo + constraints.filter { $0.localizedCaseInsensitiveContains("not visible") })
            .uniqueCaseInsensitive()
    }
}

private extension [String] {
    nonisolated func uniqueCaseInsensitive() -> [String] {
        reduce(into: []) { result, value in
            guard !result.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) else {
                return
            }

            result.append(value)
        }
    }
}
