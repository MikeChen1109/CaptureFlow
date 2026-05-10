import Foundation

struct MockCloudVisionContext: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var requestedCardType: CardType
    var resolvedCardType: CardType
    var sourceImage: CardSourceImage?
    var detectedText: [String]
    var detectedObjects: [String]
    var dateCandidates: [String]
    var timeCandidates: [String]
    var locationCandidates: [String]
    var priceCandidates: [String]
    var peopleCandidates: [String]
    var companyCandidates: [String]
    var skillCandidates: [String]
    var suggestedAction: String?
    var confidenceScore: Double

    var confidence: ConfidenceLevel {
        ConfidenceLevel.from(score: confidenceScore)
    }

    init(
        id: UUID = UUID(),
        requestedCardType: CardType,
        resolvedCardType: CardType,
        sourceImage: CardSourceImage? = nil,
        detectedText: [String] = [],
        detectedObjects: [String] = [],
        dateCandidates: [String] = [],
        timeCandidates: [String] = [],
        locationCandidates: [String] = [],
        priceCandidates: [String] = [],
        peopleCandidates: [String] = [],
        companyCandidates: [String] = [],
        skillCandidates: [String] = [],
        suggestedAction: String? = nil,
        confidenceScore: Double
    ) {
        self.id = id
        self.requestedCardType = requestedCardType
        self.resolvedCardType = resolvedCardType
        self.sourceImage = sourceImage
        self.detectedText = detectedText
        self.detectedObjects = detectedObjects
        self.dateCandidates = dateCandidates
        self.timeCandidates = timeCandidates
        self.locationCandidates = locationCandidates
        self.priceCandidates = priceCandidates
        self.peopleCandidates = peopleCandidates
        self.companyCandidates = companyCandidates
        self.skillCandidates = skillCandidates
        self.suggestedAction = suggestedAction
        self.confidenceScore = confidenceScore
    }
}
