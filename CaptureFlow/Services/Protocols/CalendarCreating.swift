import Foundation

protocol CalendarCreating: Sendable {
    func createCalendarEvent(_ request: CalendarCreationRequest) async throws -> ExternalActionResult
}
