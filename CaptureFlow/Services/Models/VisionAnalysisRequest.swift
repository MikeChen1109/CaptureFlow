import Foundation

struct VisionAnalysisRequest: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var imageData: Data?
    var sourceImage: CardSourceImage?
    var selectedCardType: CardType
    var createdAt: Date

    init(
        id: UUID = UUID(),
        imageData: Data? = nil,
        sourceImage: CardSourceImage? = nil,
        selectedCardType: CardType,
        createdAt: Date = .now
    ) {
        self.id = id
        self.imageData = imageData
        self.sourceImage = sourceImage
        self.selectedCardType = selectedCardType
        self.createdAt = createdAt
    }
}
