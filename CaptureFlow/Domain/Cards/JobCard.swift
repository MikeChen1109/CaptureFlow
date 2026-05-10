import Foundation

struct JobCard: Codable, Hashable, Identifiable, Sendable {
    var metadata: CardMetadata
    var company: String
    var role: String
    var skills: [String]
    var contact: String?
    var nextAction: String
    var followUpDate: Date?
    var notes: String
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
        company: String,
        role: String,
        skills: [String] = [],
        contact: String? = nil,
        nextAction: String,
        followUpDate: Date? = nil,
        notes: String = "",
        reminderExternalID: String? = nil
    ) {
        self.metadata = metadata
        self.company = company
        self.role = role
        self.skills = skills
        self.contact = contact
        self.nextAction = nextAction
        self.followUpDate = followUpDate
        self.notes = notes
        self.reminderExternalID = reminderExternalID
    }
}
