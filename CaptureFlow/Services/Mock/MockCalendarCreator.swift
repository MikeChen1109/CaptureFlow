import Foundation

struct MockCalendarCreator: CalendarCreating {
    func createCalendarEvent(_ request: CalendarCreationRequest) async throws -> ExternalActionResult {
        guard !request.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ServiceError.invalidGeneratedCard
        }

        guard request.endDate > request.startDate else {
            throw ServiceError.invalidGeneratedCard
        }

        return ExternalActionResult(
            kind: .calendar,
            sourceCardID: request.sourceCardID,
            externalID: "mock-calendar-\(request.id.uuidString)",
            displayName: request.title
        )
    }
}
