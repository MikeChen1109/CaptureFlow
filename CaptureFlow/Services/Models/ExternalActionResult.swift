import Foundation

struct ExternalActionResult: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var kind: ExternalActionKind
    var sourceCardID: UUID?
    var externalID: String
    var displayName: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        kind: ExternalActionKind,
        sourceCardID: UUID? = nil,
        externalID: String,
        displayName: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.kind = kind
        self.sourceCardID = sourceCardID
        self.externalID = externalID
        self.displayName = displayName
        self.createdAt = createdAt
    }
}

enum ExternalActionKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case reminder
    case calendar

    var id: String { rawValue }
}
