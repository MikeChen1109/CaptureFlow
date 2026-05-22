import Foundation

struct ReminderCard: nonisolated Codable, nonisolated Hashable, Identifiable, Sendable {
    var metadata: CardMetadata
    var title: String
    var notes: String
    var dueDate: Date?
    var location: String?
    var priority: Priority
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
        title: String,
        notes: String = "",
        dueDate: Date? = nil,
        location: String? = nil,
        priority: Priority = .none,
        reminderExternalID: String? = nil
    ) {
        self.metadata = metadata
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.location = location
        self.priority = priority
        self.reminderExternalID = reminderExternalID
    }
}

extension ReminderCard {
    enum Priority: String, nonisolated Codable, nonisolated Hashable, CaseIterable, Identifiable, Sendable {
        case none
        case low
        case medium
        case high

        var id: String { rawValue }
    }
}
