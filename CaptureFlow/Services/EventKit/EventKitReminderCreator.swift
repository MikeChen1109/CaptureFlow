import Foundation

struct EventKitReminderCreator: ReminderCreating {
    private let store: EventKitActionStore

    init(store: EventKitActionStore = EventKitActionStore()) {
        self.store = store
    }

    func createReminder(_ request: ReminderCreationRequest) async throws -> ExternalActionResult {
        try await store.createReminder(request)
    }
}
