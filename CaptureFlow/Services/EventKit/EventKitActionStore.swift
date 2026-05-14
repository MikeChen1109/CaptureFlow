import EventKit
import Foundation

actor EventKitActionStore {
    private let eventStore = EKEventStore()

    func createReminder(_ request: ReminderCreationRequest) async throws -> ExternalActionResult {
        let title = request.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            throw ServiceError.invalidGeneratedCard
        }

        try await ensureReminderAccess()

        guard let calendar = eventStore.defaultCalendarForNewReminders() else {
            throw ServiceError.unavailable("No default reminder list is available.")
        }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.calendar = calendar
        reminder.title = title
        reminder.notes = notesWithLocation(notes: request.notes, location: request.location)
        reminder.priority = eventKitPriority(for: request.priority)

        if let dueDate = request.dueDate {
            var calendar = Calendar.autoupdatingCurrent
            calendar.timeZone = .autoupdatingCurrent

            var dueDateComponents = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: dueDate
            )
            dueDateComponents.calendar = calendar
            dueDateComponents.timeZone = calendar.timeZone
            reminder.dueDateComponents = dueDateComponents
        }

        try eventStore.save(reminder, commit: true)

        return ExternalActionResult(
            kind: .reminder,
            sourceCardID: request.sourceCardID,
            externalID: reminder.calendarItemIdentifier,
            displayName: title
        )
    }

    func createCalendarEvent(_ request: CalendarCreationRequest) async throws -> ExternalActionResult {
        let title = request.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, request.endDate > request.startDate else {
            throw ServiceError.invalidGeneratedCard
        }

        try await ensureCalendarAccess()

        guard let calendar = eventStore.defaultCalendarForNewEvents else {
            throw ServiceError.unavailable("No default calendar is available.")
        }

        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.title = title
        event.startDate = request.startDate
        event.endDate = request.endDate
        event.location = request.location
        event.notes = request.notes

        try eventStore.save(event, span: .thisEvent, commit: true)

        return ExternalActionResult(
            kind: .calendar,
            sourceCardID: request.sourceCardID,
            externalID: event.eventIdentifier ?? request.id.uuidString,
            displayName: title
        )
    }

    private func ensureReminderAccess() async throws {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .authorized, .fullAccess:
            return
        case .notDetermined:
            guard try await requestFullAccessToReminders() else {
                throw ServiceError.permissionDenied
            }
        case .denied, .restricted, .writeOnly:
            throw ServiceError.permissionDenied
        @unknown default:
            throw ServiceError.permissionDenied
        }
    }

    private func ensureCalendarAccess() async throws {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .authorized, .fullAccess, .writeOnly:
            return
        case .notDetermined:
            guard try await requestFullAccessToEvents() else {
                throw ServiceError.permissionDenied
            }
        case .denied, .restricted:
            throw ServiceError.permissionDenied
        @unknown default:
            throw ServiceError.permissionDenied
        }
    }

    private func requestFullAccessToReminders() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            eventStore.requestFullAccessToReminders { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: granted)
            }
        }
    }

    private func requestFullAccessToEvents() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            eventStore.requestFullAccessToEvents { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: granted)
            }
        }
    }

    private func eventKitPriority(for priority: ReminderCard.Priority) -> Int {
        switch priority {
        case .none:
            0
        case .high:
            1
        case .medium:
            5
        case .low:
            9
        }
    }

    private func notesWithLocation(notes: String, location: String?) -> String? {
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLocation = location?.trimmingCharacters(in: .whitespacesAndNewlines)

        switch (trimmedNotes.isEmpty, trimmedLocation?.isEmpty == false ? trimmedLocation : nil) {
        case (true, nil):
            return nil
        case (true, let location?):
            return "Location: \(location)"
        case (false, nil):
            return trimmedNotes
        case (false, let location?):
            return "\(trimmedNotes)\nLocation: \(location)"
        }
    }
}
