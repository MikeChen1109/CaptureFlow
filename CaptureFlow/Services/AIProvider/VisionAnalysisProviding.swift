import Foundation

struct VisionProviderAnalysisRequest: Sendable {
    var imageData: Data
    var selectedCardType: CardType

    init(imageData: Data, selectedCardType: CardType) {
        self.imageData = imageData
        self.selectedCardType = selectedCardType
    }
}

protocol VisionAnalysisProviding: Sendable {
    var providerID: String { get }

    func analyzeImage(_ request: VisionProviderAnalysisRequest) async throws -> VisionAnalysisDTO
}
