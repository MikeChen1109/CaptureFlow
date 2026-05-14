import Combine
import Foundation
import UIKit

@MainActor
final class CardResultViewModel: ObservableObject {
    @Published private(set) var card: ActionCard
    @Published private(set) var sectionStates: [GeneratedSectionState]
    @Published private(set) var generationStatus: CardGenerationStatus
    @Published private(set) var isSaving = false
    @Published private(set) var isCreatingReminder = false
    @Published private(set) var isCreatingCalendar = false
    @Published private(set) var didSave = false
    @Published private(set) var didCreateReminder = false
    @Published private(set) var didCreateCalendar = false
    @Published private(set) var didCopyMarkdown = false
    @Published private(set) var customFields: [CardResultCustomField] = []
    @Published var errorMessage: String?
    @Published var actionMessage: String?

    private(set) var generatedContent: GeneratedCardContent?
    private(set) var sourceReasoning: [String] = []

    private let customFieldValueResolver = CardResultCustomFieldValueResolver()
    private let cardRepository: any CardRepository
    private let reminderCreator: any ReminderCreating
    private let calendarCreator: any CalendarCreating

    private var sectionStateMachine: GeneratedSectionStateMachine

    init(
        card: ActionCard,
        cardRepository: any CardRepository,
        reminderCreator: any ReminderCreating,
        calendarCreator: any CalendarCreating
    ) {
        self.card = card
        self.generatedContent = nil
        self.cardRepository = cardRepository
        self.reminderCreator = reminderCreator
        self.calendarCreator = calendarCreator

        let sectionStateMachine = GeneratedSectionStateMachine()
        self.sectionStateMachine = sectionStateMachine
        self.sectionStates = sectionStateMachine.sectionStates
        self.generationStatus = sectionStateMachine.generationStatus
    }

    var isGenerationCompleted: Bool {
        generationStatus == .completed
    }

    var canCreateReminder: Bool {
        switch card {
        case .reminder, .shopping, .job:
            true
        case .calendar, .note:
            false
        }
    }

    var canCreateCalendar: Bool {
        calendarActionState.request != nil
    }

    var calendarActionState: CardResultCalendarActionState {
        guard case .calendar(let calendar) = card else {
            return customFieldCalendarActionState
        }

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

    private var customFieldCalendarActionState: CardResultCalendarActionState {
        guard let customDate = customCalendarDate else {
            return .hidden
        }

        let trimmedTitle = card.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            return .unavailable(reason: "Add an event title before creating a calendar event.")
        }

        let startDate = customDate.combiningTime(from: customCalendarTime)
        let notes = customFields
            .filter { $0.type == .note }
            .map(\.value)
            .joined(separator: "\n")

        return .available(
            CalendarCreationRequest(
                sourceCardID: card.id,
                title: trimmedTitle,
                startDate: startDate,
                endDate: startDate.addingTimeInterval(60 * 60),
                location: customFieldValue(for: .location),
                notes: notes
            )
        )
    }

    private var customCalendarDate: Date? {
        customFields
            .filter { $0.type == .date }
            .compactMap { customFieldValueResolver.date(from: $0.value) }
            .first
    }

    private var customCalendarTime: Date? {
        customFields
            .filter { $0.type == .time }
            .compactMap { customFieldValueResolver.time(from: $0.value) }
            .first
    }

    private func customFieldValue(for type: CardResultCustomFieldType) -> String? {
        customFields
            .first { $0.type == type }?
            .value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
    }

    var showsReminderAction: Bool {
        canCreateReminder || didCreateReminder || isCreatingReminder
    }

    var showsCalendarAction: Bool {
        calendarActionState.isVisible || didCreateCalendar || isCreatingCalendar
    }

    var showsExternalActions: Bool {
        showsReminderAction || showsCalendarAction
    }

    func sectionState(for type: GeneratedSectionType) -> GeneratedSectionState {
        sectionStates.first { $0.sectionType == type }
            ?? GeneratedSectionState(sectionType: type, status: .waiting, content: nil)
    }

    func firstWaitingSection() -> GeneratedSectionState? {
        sectionStateMachine.firstWaitingSection
    }

    func applyPartialContent(_ partial: GeneratedContentPartial) {
        errorMessage = nil
        sectionStateMachine.applyPartialContent(partial)
        syncSectionState()
    }

    func completeGeneration(card: ActionCard, content: GeneratedCardContent) {
        self.card = card
        generatedContent = content

        sectionStateMachine.complete(with: content)
        syncSectionState()
    }

    func failGeneration(_ error: Error) {
        sectionStateMachine.fail()
        syncSectionState()
        actionMessage = nil
        errorMessage = "Unable to build this card: \(error.userFacingMessage)"
    }

    func resetForRetry(with card: ActionCard) {
        self.card = card
        generatedContent = nil
        sourceReasoning = []
        customFields = []
        errorMessage = nil
        actionMessage = nil

        isSaving = false
        isCreatingReminder = false
        isCreatingCalendar = false
        didSave = false
        didCreateReminder = false
        didCreateCalendar = false
        didCopyMarkdown = false

        let resetStateMachine = GeneratedSectionStateMachine()
        sectionStateMachine = resetStateMachine
        syncSectionState()
    }

    func addCustomField(type: CardResultCustomFieldType, value: String) {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            return
        }

        customFields.append(
            CardResultCustomField(
                type: type,
                value: trimmedValue
            )
        )
    }

    @discardableResult
    func removeCustomField(id: UUID) -> RemovedCardResultCustomField? {
        guard let index = customFields.firstIndex(where: { $0.id == id }) else {
            return nil
        }

        let field = customFields.remove(at: index)
        return RemovedCardResultCustomField(field: field, originalIndex: index)
    }

    func restoreCustomField(_ removed: RemovedCardResultCustomField) {
        let index = min(max(removed.originalIndex, 0), customFields.count)
        customFields.insert(removed.field, at: index)
    }

    @discardableResult
    func save() async -> Bool {
        isSaving = true
        errorMessage = nil
        actionMessage = nil

        do {
            card = try await cardRepository.save(card)
            didSave = true
            actionMessage = "Saved to local inbox."
        } catch {
            errorMessage = "Unable to save this card."
            isSaving = false
            return false
        }

        isSaving = false
        return true
    }

    func copyMarkdown() {
        UIPasteboard.general.string = card.markdown
        didCopyMarkdown = true
        actionMessage = "Markdown copied."
        errorMessage = nil
    }

    func createReminder() async {
        guard canCreateReminder,
              let request = card.reminderRequestForCardResult()
        else {
            errorMessage = "This card type does not support reminders."
            return
        }

        isCreatingReminder = true
        errorMessage = nil
        actionMessage = nil

        do {
            let result = try await reminderCreator.createReminder(request)
            card = card.applyingReminderResult(result)
            try await persistIfNeeded()
            didCreateReminder = true
            actionMessage = "Reminder created."
        } catch {
            errorMessage = "Unable to create reminder: \(error.userFacingMessage)"
        }

        isCreatingReminder = false
    }

    func createCalendarEvent() async {
        guard let request = calendarActionState.request else {
            errorMessage = calendarActionState.unavailableReason ?? "This card type does not support calendar events."
            return
        }

        isCreatingCalendar = true
        errorMessage = nil
        actionMessage = nil

        do {
            let result = try await calendarCreator.createCalendarEvent(request)
            card = card.applyingCalendarResult(result)
            try await persistIfNeeded()
            didCreateCalendar = true
            actionMessage = "Calendar event created."
        } catch {
            errorMessage = "Unable to create calendar event: \(error.userFacingMessage)"
        }

        isCreatingCalendar = false
    }

    private func syncSectionState() {
        sectionStates = sectionStateMachine.sectionStates
        generationStatus = sectionStateMachine.generationStatus
        sourceReasoning = sectionStateMachine.sourceReasoning
    }

    private func persistIfNeeded() async throws {
        guard didSave else { return }
        card = try await cardRepository.update(card)
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

private extension Date {
    func combiningTime(from time: Date?) -> Date {
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent

        var dateComponents = calendar.dateComponents([.year, .month, .day], from: self)
        let timeComponents = time.map {
            calendar.dateComponents([.hour, .minute], from: $0)
        }

        dateComponents.hour = timeComponents?.hour ?? 9
        dateComponents.minute = timeComponents?.minute ?? 0

        return calendar.date(from: dateComponents) ?? self
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}

private extension Error {
    var userFacingMessage: String {
        if let serviceError = self as? ServiceError {
            return serviceError.userFacingMessage
        }

        return String(describing: self)
    }
}

private extension ServiceError {
    var userFacingMessage: String {
        switch self {
        case .noImageProvided:
            "No image data was provided."
        case .unsupportedCardType(let cardType):
            "Unsupported card type: \(cardType.rawValue)."
        case .insufficientCredits:
            "No mock credits remaining."
        case .permissionDenied:
            "Permission denied."
        case .invalidGeneratedCard:
            "The generated card was missing required fields."
        case .unavailable(let message):
            message
        }
    }
}
