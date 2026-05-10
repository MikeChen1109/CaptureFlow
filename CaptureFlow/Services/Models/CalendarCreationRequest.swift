import Foundation

struct CalendarCreationRequest: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var sourceCardID: UUID?
    var title: String
    var startDate: Date
    var endDate: Date
    var location: String?
    var notes: String

    init(
        id: UUID = UUID(),
        sourceCardID: UUID? = nil,
        title: String,
        startDate: Date,
        endDate: Date,
        location: String? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.sourceCardID = sourceCardID
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.notes = notes
    }

    init(card: CalendarCard) {
        self.init(
            sourceCardID: card.id,
            title: card.title,
            startDate: card.startDate,
            endDate: card.endDate,
            location: card.location,
            notes: card.notes
        )
    }
}
