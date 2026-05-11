import Foundation

protocol VisionAnalyzing: Sendable {
    func analyze(_ request: VisionAnalysisRequest) async throws -> VisionUnderstandingContext
}
