import Foundation

extension ActionCard {
    func updatingPersonalNote(_ value: String) -> ActionCard {
        switch self {
        case .reminder(var reminder):
            reminder.notes = value
            reminder.metadata.updatedAt = .now
            return .reminder(reminder)
        case .calendar(var calendar):
            calendar.notes = value
            calendar.metadata.updatedAt = .now
            return .calendar(calendar)
        case .note:
            return self
        case .shopping(var shopping):
            shopping.notes = value
            shopping.metadata.updatedAt = .now
            return .shopping(shopping)
        case .job(var job):
            job.notes = value
            job.metadata.updatedAt = .now
            return .job(job)
        }
    }

    func applyingReminderResult(_ result: ExternalActionResult) -> ActionCard {
        switch self {
        case .reminder(var reminder):
            reminder.reminderExternalID = result.externalID
            reminder.metadata.status = .completed
            reminder.metadata.updatedAt = .now
            return .reminder(reminder)
        case .shopping(var shopping):
            shopping.reminderExternalID = result.externalID
            shopping.metadata.status = .completed
            shopping.metadata.updatedAt = .now
            return .shopping(shopping)
        case .job(var job):
            job.reminderExternalID = result.externalID
            job.metadata.status = .completed
            job.metadata.updatedAt = .now
            return .job(job)
        case .calendar, .note:
            return self
        }
    }

    func applyingCalendarResult(_ result: ExternalActionResult) -> ActionCard {
        guard case .calendar(var calendar) = self else {
            return self
        }

        calendar.calendarExternalID = result.externalID
        calendar.metadata.status = .completed
        calendar.metadata.updatedAt = .now
        return .calendar(calendar)
    }

    func reminderRequestForCardResult() -> ReminderCreationRequest? {
        switch self {
        case .reminder(let reminder):
            return ReminderCreationRequest(card: reminder)
        case .shopping(let shopping):
            return ReminderCreationRequest(
                sourceCardID: shopping.id,
                title: "Buy \(shopping.productName)",
                notes: shopping.notes,
                dueDate: shopping.date,
                location: shopping.merchant,
                priority: .medium
            )
        case .job(let job):
            return ReminderCreationRequest(
                sourceCardID: job.id,
                title: job.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "Review \(job.role) at \(job.company)"
                    : job.detail,
                notes: job.notes,
                dueDate: job.date,
                location: job.company,
                priority: .medium
            )
        case .calendar, .note:
            return nil
        }
    }

    var calendarRequestForCardResult: CalendarCreationRequest? {
        guard case .calendar(let calendar) = self else {
            return nil
        }

        return CalendarCreationRequest(card: calendar)
    }
}
