import Foundation

struct EventKitCalendarCreator: CalendarCreating {
    private let store: EventKitActionStore

    init(store: EventKitActionStore = EventKitActionStore()) {
        self.store = store
    }

    func createCalendarEvent(_ request: CalendarCreationRequest) async throws -> ExternalActionResult {
        try await store.createCalendarEvent(request)
    }
}
