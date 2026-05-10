import Foundation

protocol ReminderCreating: Sendable {
    func createReminder(_ request: ReminderCreationRequest) async throws -> ExternalActionResult
}
