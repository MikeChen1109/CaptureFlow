import Foundation

struct VisionUnderstandingContext: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var requestedCardType: CardType
    var resolvedCardType: CardType
    var sourceImage: CardSourceImage?
    var sceneTitle: String
    var sceneSummary: String
    var userIntentGuess: String
    var visibleText: [String]
    var visualObjects: [String]
    var layoutDescription: String
    var entities: [VisionEntity]
    var possibleActions: [VisionActionHint]
    var constraints: [String]
    var missingInfo: [String]
    var recommendedPlanTitle: String
    var draftIntent: String
    var confidenceScore: Double
    var evidence: [String]

    var confidence: ConfidenceLevel {
        ConfidenceLevel.from(score: confidenceScore)
    }

    init(
        id: UUID = UUID(),
        requestedCardType: CardType,
        resolvedCardType: CardType,
        sourceImage: CardSourceImage? = nil,
        sceneTitle: String,
        sceneSummary: String,
        userIntentGuess: String,
        visibleText: [String] = [],
        visualObjects: [String] = [],
        layoutDescription: String,
        entities: [VisionEntity] = [],
        possibleActions: [VisionActionHint] = [],
        constraints: [String] = [],
        missingInfo: [String] = [],
        recommendedPlanTitle: String,
        draftIntent: String,
        confidenceScore: Double,
        evidence: [String] = []
    ) {
        self.id = id
        self.requestedCardType = requestedCardType
        self.resolvedCardType = resolvedCardType
        self.sourceImage = sourceImage
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
        self.draftIntent = draftIntent
        self.confidenceScore = confidenceScore
        self.evidence = evidence
    }
}

struct VisionEntity: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var type: VisionEntityType
    var label: String
    var value: String
    var confidence: Double

    init(
        id: UUID = UUID(),
        type: VisionEntityType,
        label: String,
        value: String,
        confidence: Double
    ) {
        self.id = id
        self.type = type
        self.label = label
        self.value = value
        self.confidence = confidence
    }
}

enum VisionEntityType: String, Codable, CaseIterable, Identifiable, Sendable {
    case product
    case price
    case promotion
    case store
    case date
    case time
    case location
    case company
    case role
    case skill
    case url
    case contact
    case note
    case event
    case unknown

    var id: String { rawValue }
}

struct VisionActionHint: Codable, Hashable, Identifiable, Sendable {
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

enum VisionActionType: String, Codable, CaseIterable, Identifiable, Sendable {
    case save
    case reminder
    case calendar
    case copy
    case share
    case compare
    case followUp
    case custom

    var id: String { rawValue }
}
