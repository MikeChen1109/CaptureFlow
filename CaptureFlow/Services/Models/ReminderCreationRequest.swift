import Foundation

struct ReminderCreationRequest: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var sourceCardID: UUID?
    var title: String
    var notes: String
    var dueDate: Date?
    var location: String?
    var priority: ReminderCard.Priority

    nonisolated init(
        id: UUID = UUID(),
        sourceCardID: UUID? = nil,
        title: String,
        notes: String = "",
        dueDate: Date? = nil,
        location: String? = nil,
        priority: ReminderCard.Priority = .none
    ) {
        self.id = id
        self.sourceCardID = sourceCardID
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.location = location
        self.priority = priority
    }

    nonisolated init(card: ReminderCard) {
        self.init(
            sourceCardID: card.metadata.id,
            title: card.title,
            notes: card.notes,
            dueDate: card.dueDate,
            location: card.location,
            priority: card.priority
        )
    }
}
