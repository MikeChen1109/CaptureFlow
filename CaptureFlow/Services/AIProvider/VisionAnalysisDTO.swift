import Foundation

struct VisionAnalysisDTO: Codable, Hashable, Sendable {
    var resolvedCardType: CardType?
    var cardType: CardType?
    var sceneTitle: String
    var sceneSummary: String
    var userIntentGuess: String
    var visibleText: [String]
    var visualObjects: [String]
    var layoutDescription: String
    var entities: [VisionEntityDTO]
    var possibleActions: [VisionActionHintDTO]
    var constraints: [String]
    var missingInfo: [String]
    var recommendedPlanTitle: String
    var confidenceScore: Double
    var evidence: [String]

    init(
        resolvedCardType: CardType? = nil,
        cardType: CardType? = nil,
        sceneTitle: String,
        sceneSummary: String,
        userIntentGuess: String = "",
        visibleText: [String] = [],
        visualObjects: [String] = [],
        layoutDescription: String = "",
        entities: [VisionEntityDTO] = [],
        possibleActions: [VisionActionHintDTO] = [],
        constraints: [String] = [],
        missingInfo: [String] = [],
        recommendedPlanTitle: String = "",
        confidenceScore: Double,
        evidence: [String] = []
    ) {
        self.resolvedCardType = resolvedCardType
        self.cardType = cardType
        self.sceneTitle = sceneTitle
        self.sceneSummary = sceneSummary
        self.userIntentGuess = userIntentGuess
        self.visibleText = visibleText
        self.visualObjects = visualObjects
        self.layoutDescription = layoutDescription
        self.entities = entities
        self.possibleActions = possibleActions
        self.constraints = constraints
        self.missingInfo = missingInfo
        self.recommendedPlanTitle = recommendedPlanTitle
        self.confidenceScore = confidenceScore
        self.evidence = evidence
    }
}

struct VisionEntityDTO: Codable, Hashable, Sendable {
    var type: String
    var label: String
    var value: String
    var confidence: Double

    init(
        type: String,
        label: String,
        value: String,
        confidence: Double = 0
    ) {
        self.type = type
        self.label = label
        self.value = value
        self.confidence = confidence
    }
}

struct VisionActionHintDTO: Codable, Hashable, Sendable {
    var title: String
    var description: String
    var actionType: String

    init(
        title: String,
        description: String,
        actionType: String
    ) {
        self.title = title
        self.description = description
        self.actionType = actionType
    }
}

extension VisionAnalysisDTO {
    func understandingContext(from request: VisionAnalysisRequest) -> VisionUnderstandingContext {
        let resolvedCardType = resolvedCardType ?? cardType ?? request.selectedCardType

        return VisionUnderstandingContext(
            requestedCardType: request.selectedCardType,
            resolvedCardType: resolvedCardType,
            sourceImage: request.sourceImage,
            sceneTitle: sceneTitle.nonEmpty(or: "Screenshot Insight"),
            sceneSummary: sceneSummary,
            userIntentGuess: userIntentGuess,
            visibleText: visibleText,
            visualObjects: visualObjects,
            layoutDescription: layoutDescription,
            entities: entities.map(\.visionEntity),
            possibleActions: possibleActions.map(\.visionActionHint),
            constraints: constraints,
            missingInfo: missingInfo,
            recommendedPlanTitle: recommendedPlanTitle.nonEmpty(or: "Recommended Plan"),
            confidenceScore: confidenceScore.clamped(to: 0...1),
            evidence: evidence
        )
    }
}

private extension VisionEntityDTO {
    var visionEntity: VisionEntity {
        VisionEntity(
            type: VisionEntityType(rawValue: type) ?? .unknown,
            label: label,
            value: value,
            confidence: confidence.clamped(to: 0...1)
        )
    }
}

private extension VisionActionHintDTO {
    var visionActionHint: VisionActionHint {
        VisionActionHint(
            title: title,
            description: description,
            actionType: VisionActionType(rawValue: actionType) ?? .custom
        )
    }
}

private extension String {
    func nonEmpty(or fallback: String) -> String {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : self
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
