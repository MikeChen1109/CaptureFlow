import Foundation

enum ActionCard: Codable, Hashable, Identifiable, Sendable {
    case reminder(ReminderCard)
    case calendar(CalendarCard)
    case note(NoteCard)
    case shopping(ShoppingCard)
    case job(JobCard)

    nonisolated var id: UUID {
        metadata.id
    }

    nonisolated var type: CardType {
        switch self {
        case .reminder:
            .reminder
        case .calendar:
            .calendar
        case .note:
            .note
        case .shopping:
            .shopping
        case .job:
            .job
        }
    }

    nonisolated var metadata: CardMetadata {
        switch self {
        case .reminder(let card):
            card.metadata
        case .calendar(let card):
            card.metadata
        case .note(let card):
            card.metadata
        case .shopping(let card):
            card.metadata
        case .job(let card):
            card.metadata
        }
    }

    nonisolated var title: String {
        switch self {
        case .reminder(let card):
            card.title
        case .calendar(let card):
            card.title
        case .note(let card):
            card.title
        case .shopping(let card):
            card.productName
        case .job(let card):
            "\(card.role) at \(card.company)"
        }
    }

    nonisolated var createdAt: Date { metadata.createdAt }
    nonisolated var updatedAt: Date { metadata.updatedAt }
    nonisolated var sourceImage: CardSourceImage? { metadata.sourceImage }
    nonisolated var confidence: ConfidenceLevel { metadata.confidence }
    nonisolated var confidenceScore: Double { metadata.confidenceScore }
    nonisolated var status: CardStatus { metadata.status }

    nonisolated var reminderExternalID: String? {
        switch self {
        case .reminder(let card):
            card.reminderExternalID
        case .shopping(let card):
            card.reminderExternalID
        case .job(let card):
            card.reminderExternalID
        case .calendar, .note:
            nil
        }
    }

    nonisolated var calendarExternalID: String? {
        guard case .calendar(let card) = self else {
            return nil
        }

        return card.calendarExternalID
    }

    nonisolated func updatingMetadata(_ transform: (inout CardMetadata) -> Void) -> ActionCard {
        switch self {
        case .reminder(var card):
            transform(&card.metadata)
            return .reminder(card)
        case .calendar(var card):
            transform(&card.metadata)
            return .calendar(card)
        case .note(var card):
            transform(&card.metadata)
            return .note(card)
        case .shopping(var card):
            transform(&card.metadata)
            return .shopping(card)
        case .job(var card):
            transform(&card.metadata)
            return .job(card)
        }
    }

    nonisolated func updatingStatus(_ status: CardStatus, updatedAt: Date = .now) -> ActionCard {
        updatingMetadata { metadata in
            metadata.status = status
            metadata.updatedAt = updatedAt
        }
    }
}
