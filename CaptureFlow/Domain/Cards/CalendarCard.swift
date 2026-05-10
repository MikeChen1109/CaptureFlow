import Foundation

struct CalendarCard: Codable, Hashable, Identifiable, Sendable {
    var metadata: CardMetadata
    var title: String
    var startDate: Date
    var endDate: Date
    var location: String?
    var notes: String
    var calendarExternalID: String?

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
        startDate: Date,
        endDate: Date,
        location: String? = nil,
        notes: String = "",
        calendarExternalID: String? = nil
    ) {
        self.metadata = metadata
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.notes = notes
        self.calendarExternalID = calendarExternalID
    }
}
