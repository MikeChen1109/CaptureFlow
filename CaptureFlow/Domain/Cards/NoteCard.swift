import Foundation

struct NoteCard: Codable, Hashable, Identifiable, Sendable {
    var metadata: CardMetadata
    var title: String
    var summary: String
    var bullets: [String]
    var todos: [String]

    var id: UUID { metadata.id }
    var createdAt: Date { metadata.createdAt }
    var updatedAt: Date { metadata.updatedAt }
    var sourceImage: CardSourceImage? { metadata.sourceImage }
    var confidence: ConfidenceLevel { metadata.confidence }
    var confidenceScore: Double { metadata.confidenceScore }
    var status: CardStatus { metadata.status }

    init(
        metadata: CardMetadata,
        title: String,
        summary: String,
        bullets: [String] = [],
        todos: [String] = []
    ) {
        self.metadata = metadata
        self.title = title
        self.summary = summary
        self.bullets = bullets
        self.todos = todos
    }
}
