import Foundation

struct ProviderVisionAnalyzer: VisionAnalyzing {
    private let provider: any VisionAnalysisProviding
    private let imagePayloadOptimizer: VisionImagePayloadOptimizer

    init(
        provider: any VisionAnalysisProviding,
        imagePayloadOptimizer: VisionImagePayloadOptimizer = VisionImagePayloadOptimizer()
    ) {
        self.provider = provider
        self.imagePayloadOptimizer = imagePayloadOptimizer
    }

    func analyze(_ request: VisionAnalysisRequest) async throws -> VisionUnderstandingContext {
        guard let imageData = request.imageData else {
            throw ServiceError.noImageProvided
        }

        let providerRequest = VisionProviderAnalysisRequest(
            imageData: imagePayloadOptimizer.optimizedImageData(from: imageData),
            selectedCardType: request.selectedCardType
        )
        let dto = try await provider.analyzeImage(providerRequest)

        return dto.understandingContext(from: request)
    }
}
