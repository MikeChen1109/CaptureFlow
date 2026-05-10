import Foundation

protocol CardGenerating: Sendable {
    func generateCard(from context: MockCloudVisionContext) async throws -> ActionCard
}
