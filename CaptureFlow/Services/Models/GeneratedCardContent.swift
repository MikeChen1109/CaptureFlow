import Foundation

struct GeneratedCardContent: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var summary: String
    var planTitle: String
    var planSteps: [GeneratedPlanStep]
    var keyDetails: [GeneratedField]
    var recommendedActions: [GeneratedAction]
    var draftOutput: GeneratedDraft
    var missingInfo: [String]
    var sourceReasoning: [String]
    var personalNotePlaceholder: String

    init(
        id: UUID = UUID(),
        summary: String,
        planTitle: String,
        planSteps: [GeneratedPlanStep],
        keyDetails: [GeneratedField],
        recommendedActions: [GeneratedAction],
        draftOutput: GeneratedDraft,
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
        self.draftOutput = draftOutput
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

    init(
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

    init(
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

    init(
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

struct GeneratedDraft: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var type: GeneratedDraftType
    var title: String
    var body: String

    init(
        id: UUID = UUID(),
        type: GeneratedDraftType,
        title: String,
        body: String
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.body = body
    }
}

enum GeneratedDraftType: String, Codable, CaseIterable, Identifiable, Sendable {
    case reminder
    case calendar
    case note
    case shopping
    case job
    case summary
    case custom

    var id: String { rawValue }
}

extension GeneratedCardContent {
    static func fallback(from context: VisionUnderstandingContext) -> GeneratedCardContent {
        GeneratedCardContent(
            summary: context.sceneSummary,
            planTitle: context.recommendedPlanTitle,
            planSteps: context.generatedPlanSteps,
            keyDetails: context.generatedKeyDetails,
            recommendedActions: context.generatedRecommendedActions,
            draftOutput: GeneratedDraft(
                type: context.generatedDraftType,
                title: context.recommendedPlanTitle,
                body: context.draftIntent
            ),
            missingInfo: context.generatedMissingInfo,
            sourceReasoning: context.evidence,
            personalNotePlaceholder: "Add your own note..."
        )
    }
}

extension VisionUnderstandingContext {
    var generatedPlanSteps: [GeneratedPlanStep] {
        let steps = possibleActions.map {
            GeneratedPlanStep(
                title: $0.title,
                detail: $0.description,
                actionType: $0.actionType
            )
        }

        guard !steps.isEmpty else {
            return [
                GeneratedPlanStep(
                    title: recommendedPlanTitle,
                    detail: draftIntent,
                    actionType: .save
                )
            ]
        }

        return steps
    }

    var generatedKeyDetails: [GeneratedField] {
        entities.map {
            GeneratedField(
                label: $0.label,
                value: $0.value,
                type: $0.type,
                confidence: $0.confidence
            )
        }
    }

    var generatedRecommendedActions: [GeneratedAction] {
        possibleActions.map {
            GeneratedAction(
                title: $0.title,
                description: $0.description,
                actionType: $0.actionType
            )
        }
    }

    var generatedMissingInfo: [String] {
        (missingInfo + constraints.filter { $0.localizedCaseInsensitiveContains("not visible") })
            .uniqueCaseInsensitive()
    }

    var generatedDraftType: GeneratedDraftType {
        switch resolvedCardType {
        case .auto:
            .summary
        case .reminder:
            .reminder
        case .calendar:
            .calendar
        case .note:
            .note
        case .shopping:
            .shopping
        case .job:
            .job
        }
    }
}

private extension [String] {
    func uniqueCaseInsensitive() -> [String] {
        reduce(into: []) { result, value in
            guard !result.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) else {
                return
            }

            result.append(value)
        }
    }
}
