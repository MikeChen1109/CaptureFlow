import Foundation

struct CardResultCalendarActionResolver {
    func actionState(
        for card: ActionCard,
        customFields: [CardResultCustomField]
    ) -> CardResultCalendarActionState {
        switch card {
        case .calendar(let calendar):
            return calendarActionState(for: calendar)
        default:
            return customFieldCalendarActionState(
                card: card,
                customFields: customFields
            )
        }
    }

    private func calendarActionState(for calendar: CalendarCard) -> CardResultCalendarActionState {
        let trimmedTitle = calendar.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            return .unavailable(reason: "Add an event title before creating a calendar event.")
        }

        let endDate = calendar.endDate > calendar.startDate
            ? calendar.endDate
            : calendar.startDate.addingTimeInterval(60 * 60)

        return .available(
            CalendarCreationRequest(
                sourceCardID: calendar.id,
                title: trimmedTitle,
                startDate: calendar.startDate,
                endDate: endDate,
                location: calendar.location,
                notes: calendar.notes
            )
        )
    }

    private func customFieldCalendarActionState(
        card: ActionCard,
        customFields: [CardResultCustomField]
    ) -> CardResultCalendarActionState {
        let fieldValues = CardResultCustomFieldValues(fields: customFields)
        guard let startDate = fieldValues.combinedDateTime else {
            return .hidden
        }

        let trimmedTitle = card.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            return .unavailable(reason: "Add an event title before creating a calendar event.")
        }

        return .available(
            CalendarCreationRequest(
                sourceCardID: card.id,
                title: trimmedTitle,
                startDate: startDate,
                endDate: startDate.addingTimeInterval(60 * 60),
                location: fieldValues.firstValue(for: .location),
                notes: fieldValues.joinedValues(for: .note)
            )
        )
    }
}

enum CardResultCalendarActionState: Equatable, Sendable {
    case hidden
    case unavailable(reason: String)
    case available(CalendarCreationRequest)

    var isVisible: Bool {
        switch self {
        case .hidden:
            return false
        case .unavailable, .available:
            return true
        }
    }

    var request: CalendarCreationRequest? {
        guard case .available(let request) = self else {
            return nil
        }

        return request
    }

    var unavailableReason: String? {
        guard case .unavailable(let reason) = self else {
            return nil
        }

        return reason
    }
}
