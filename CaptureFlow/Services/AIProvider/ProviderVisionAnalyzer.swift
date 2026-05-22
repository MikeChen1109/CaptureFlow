import Foundation

struct ProviderVisionAnalyzer: VisionAnalyzing {
    private let provider: any VisionAnalysisProviding

    init(provider: any VisionAnalysisProviding) {
        self.provider = provider
    }

    func analyze(_ request: VisionAnalysisRequest) async throws -> VisionUnderstandingContext {
        guard let imageData = request.imageData else {
            throw ServiceError.noImageProvided
        }

        let providerRequest = VisionProviderAnalysisRequest(
            imageData: imageData,
            selectedCardType: request.selectedCardType
        )
        let dto = try await provider.analyzeImage(providerRequest)

        return dto.understandingContext(from: request)
    }
}
