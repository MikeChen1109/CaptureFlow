import Foundation

struct CardMetadata: nonisolated Codable, nonisolated Hashable, Identifiable, Sendable {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var sourceImage: CardSourceImage?
    var cardType: CardType?
    var confidence: ConfidenceLevel
    var confidenceScore: Double
    var status: CardStatus

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        sourceImage: CardSourceImage? = nil,
        cardType: CardType? = nil,
        confidence: ConfidenceLevel,
        confidenceScore: Double,
        status: CardStatus = .pending
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sourceImage = sourceImage
        self.cardType = cardType
        self.confidence = confidence
        self.confidenceScore = confidenceScore
        self.status = status
    }
}
