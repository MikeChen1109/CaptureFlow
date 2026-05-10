import Foundation

struct MockReminderCreator: ReminderCreating {
    func createReminder(_ request: ReminderCreationRequest) async throws -> ExternalActionResult {
        guard !request.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ServiceError.invalidGeneratedCard
        }

        return ExternalActionResult(
            kind: .reminder,
            sourceCardID: request.sourceCardID,
            externalID: "mock-reminder-\(request.id.uuidString)",
            displayName: request.title
        )
    }
}
