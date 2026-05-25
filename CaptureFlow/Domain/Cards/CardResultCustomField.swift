import Foundation

struct CardResultCustomField: nonisolated Codable, nonisolated Hashable, Identifiable, Sendable {
    var id: UUID
    var type: CardResultCustomFieldType
    var value: String

    init(
        id: UUID = UUID(),
        type: CardResultCustomFieldType,
        value: String
    ) {
        self.id = id
        self.type = type
        self.value = value
    }
}

enum CardResultCustomFieldType: String, nonisolated Codable, nonisolated Hashable, CaseIterable, Identifiable, Sendable {
    case note
    case date
    case time
    case location
    case link
    case contact
    case custom

    var id: String { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .note:
            "Note"
        case .date:
            "Date"
        case .time:
            "Time"
        case .location:
            "Location"
        case .link:
            "Link"
        case .contact:
            "Contact"
        case .custom:
            "Custom"
        }
    }
}
