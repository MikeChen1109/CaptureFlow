import Foundation

enum CardType: String, nonisolated Codable, nonisolated Hashable, CaseIterable, Identifiable, Sendable {
    case unknown
    case shopping
    case event
    case note
    case job
    case travel
    case food
    case receipt
    case article
    case product
    case reminder
    case contact
    case promotion
    case document
    case appScreen
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .unknown:
            "Unknown"
        case .shopping:
            "Shopping"
        case .event:
            "Event"
        case .note:
            "Note"
        case .job:
            "Job"
        case .travel:
            "Travel"
        case .food:
            "Food"
        case .receipt:
            "Receipt"
        case .article:
            "Article"
        case .product:
            "Product"
        case .reminder:
            "Reminder"
        case .contact:
            "Contact"
        case .promotion:
            "Promotion"
        case .document:
            "Document"
        case .appScreen:
            "App Screen"
        case .other:
            "Other"
        }
    }
}

extension CardType {
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        switch rawValue {
        case "auto":
            self = .unknown
        case "calendar":
            self = .event
        default:
            self = CardType(rawValue: rawValue) ?? .unknown
        }
    }
}
