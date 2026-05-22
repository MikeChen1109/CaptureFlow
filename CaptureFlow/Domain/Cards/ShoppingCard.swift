import Foundation

struct ShoppingCard: nonisolated Codable, nonisolated Hashable, Identifiable, Sendable {
    var metadata: CardMetadata
    var productName: String
    var price: String?
    var merchant: String?
    var offer: String?
    var date: Date?
    var notes: String
    var reminderExternalID: String?

    var id: UUID { metadata.id }
    var createdAt: Date { metadata.createdAt }
    var updatedAt: Date { metadata.updatedAt }
    var sourceImage: CardSourceImage? { metadata.sourceImage }
    var confidence: ConfidenceLevel { metadata.confidence }
    var confidenceScore: Double { metadata.confidenceScore }
    var status: CardStatus { metadata.status }

    init(
        metadata: CardMetadata,
        productName: String,
        price: String? = nil,
        merchant: String? = nil,
        offer: String? = nil,
        date: Date? = nil,
        notes: String = "",
        reminderExternalID: String? = nil
    ) {
        self.metadata = metadata
        self.productName = productName
        self.price = price
        self.merchant = merchant
        self.offer = offer
        self.date = date
        self.notes = notes
        self.reminderExternalID = reminderExternalID
    }
}
