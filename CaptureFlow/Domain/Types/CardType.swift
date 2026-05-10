import Foundation

enum CardType: String, Codable, CaseIterable, Identifiable, Sendable {
    case auto
    case reminder
    case calendar
    case note
    case shopping
    case job

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto:
            "Auto"
        case .reminder:
            "Reminder"
        case .calendar:
            "Calendar"
        case .note:
            "Note"
        case .shopping:
            "Shopping"
        case .job:
            "Job"
        }
    }
}
