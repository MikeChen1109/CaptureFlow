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
        if case .calendar = card {
            return true
        }

        return false
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
    func removeCustomField(id: UUID) -> RemovedCustomField? {
        guard let index = customFields.firstIndex(where: { $0.id == id }) else {
            return nil
        }

        let field = customFields.remove(at: index)
        return RemovedCustomField(field: field, originalIndex: index)
    }

    func restoreCustomField(_ removed: RemovedCustomField) {
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
            actionMessage = "Mock reminder created."
        } catch {
            errorMessage = "Unable to create reminder for this card."
        }

        isCreatingReminder = false
    }

    func createCalendarEvent() async {
        guard let request = card.calendarRequestForCardResult else {
            errorMessage = "This card type does not support calendar events."
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
            actionMessage = "Mock calendar event created."
        } catch {
            errorMessage = "Unable to create calendar event for this card."
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

struct CardResultCustomField: Identifiable, Equatable, Sendable {
    var id: UUID
    var type: CardResultCustomFieldType
    var value: String

    init(
        id: UUID = UUID(),
        type: CardResultCustomFieldType,
        value: String
    ) {
        self.id = id
        self.type = type
        self.value = value
    }
}

struct RemovedCustomField: Equatable, Sendable {
    var field: CardResultCustomField
    var originalIndex: Int
}

enum CardResultCustomFieldType: String, CaseIterable, Identifiable, Sendable {
    case note
    case date
    case time
    case location
    case link
    case contact
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .note:
            "Note"
        case .date:
            "Date"
        case .time:
            "Time"
        case .location:
            "Location"
        case .link:
            "Link"
        case .contact:
            "Contact"
        case .custom:
            "Custom"
        }
    }

    var systemImage: String {
        switch self {
        case .note:
            "note.text"
        case .date:
            "calendar"
        case .time:
            "clock"
        case .location:
            "mappin.and.ellipse"
        case .link:
            "link"
        case .contact:
            "person.crop.circle.badge.plus"
        case .custom:
            "square.and.pencil"
        }
    }

    var placeholder: String {
        switch self {
        case .note:
            "Add a note..."
        case .date:
            ""
        case .time:
            ""
        case .location:
            "Add a location..."
        case .link:
            "Paste a URL..."
        case .contact:
            "Add contact info..."
        case .custom:
            "Add custom field value..."
        }
    }

    var helperDescription: String {
        switch self {
        case .note:
            "Capture short context or follow-up notes."
        case .date:
            "Pick a date and it will be saved in a readable format."
        case .time:
            "Pick a time for reminders or scheduling details."
        case .location:
            "Store where this action should happen."
        case .link:
            "Save a useful URL. Missing scheme will auto-use https://."
        case .contact:
            "Store contact info like name, email, or phone."
        case .custom:
            "Use this for any additional detail not covered above."
        }
    }

    var keyboardType: UIKeyboardType {
        switch self {
        case .link:
            .URL
        case .contact:
            .emailAddress
        default:
            .default
        }
    }

    var textContentType: UITextContentType? {
        switch self {
        case .location:
            .fullStreetAddress
        case .link:
            .URL
        case .contact:
            .name
        default:
            nil
        }
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
