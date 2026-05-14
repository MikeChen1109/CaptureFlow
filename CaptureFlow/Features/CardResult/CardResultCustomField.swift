import Foundation
import UIKit

struct CardResultCustomField: Identifiable, Equatable, Sendable {
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

struct RemovedCardResultCustomField: Equatable, Sendable {
    var field: CardResultCustomField
    var originalIndex: Int
}

enum CardResultCustomFieldType: String, CaseIterable, Identifiable, Sendable {
    case note
    case date
    case time
    case location
    case link
    case contact
    case custom

    var id: String { rawValue }

    var displayName: String {
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

    var systemImage: String {
        switch self {
        case .note:
            "note.text"
        case .date:
            "calendar"
        case .time:
            "clock"
        case .location:
            "mappin.and.ellipse"
        case .link:
            "link"
        case .contact:
            "person.crop.circle.badge.plus"
        case .custom:
            "square.and.pencil"
        }
    }

    var placeholder: String {
        switch self {
        case .note:
            "Add a note..."
        case .date:
            ""
        case .time:
            ""
        case .location:
            "Add a location..."
        case .link:
            "Paste a URL..."
        case .contact:
            "Add contact info..."
        case .custom:
            "Add custom field value..."
        }
    }

    var helperDescription: String {
        switch self {
        case .note:
            "Capture short context or follow-up notes."
        case .date:
            "Pick a date and it will be saved in a readable format."
        case .time:
            "Pick a time for reminders or scheduling details."
        case .location:
            "Store where this action should happen."
        case .link:
            "Save a useful URL. Missing scheme will auto-use https://."
        case .contact:
            "Store contact info like name, email, or phone."
        case .custom:
            "Use this for any additional detail not covered above."
        }
    }

    var keyboardType: UIKeyboardType {
        switch self {
        case .link:
            .URL
        case .contact:
            .emailAddress
        default:
            .default
        }
    }

    var textContentType: UITextContentType? {
        switch self {
        case .location:
            .fullStreetAddress
        case .link:
            .URL
        case .contact:
            .name
        default:
            nil
        }
    }
}
