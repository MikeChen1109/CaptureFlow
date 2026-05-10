import Combine
import Foundation
import UIKit

@MainActor
final class CardResultViewModel: ObservableObject {
    @Published private(set) var card: ActionCard
    @Published private(set) var isSaving = false
    @Published private(set) var isCreatingReminder = false
    @Published private(set) var isCreatingCalendar = false
    @Published private(set) var didSave = false
    @Published private(set) var didCreateReminder = false
    @Published private(set) var didCreateCalendar = false
    @Published private(set) var didCopyMarkdown = false
    @Published var errorMessage: String?
    @Published var actionMessage: String?

    private let cardRepository: any CardRepository
    private let reminderCreator: any ReminderCreating
    private let calendarCreator: any CalendarCreating

    init(
        card: ActionCard,
        cardRepository: any CardRepository,
        reminderCreator: any ReminderCreating,
        calendarCreator: any CalendarCreating
    ) {
        self.card = card
        self.cardRepository = cardRepository
        self.reminderCreator = reminderCreator
        self.calendarCreator = calendarCreator
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

    func save() async {
        isSaving = true
        errorMessage = nil
        actionMessage = nil

        do {
            card = try await cardRepository.save(card)
            didSave = true
            actionMessage = "Saved to local inbox."
        } catch {
            errorMessage = "Unable to save this card."
        }

        isSaving = false
    }

    func copyMarkdown() {
        UIPasteboard.general.string = card.markdown
        didCopyMarkdown = true
        actionMessage = "Markdown copied."
        errorMessage = nil
    }

    func createReminder() async {
        guard canCreateReminder else {
            errorMessage = "This card type does not support reminders."
            return
        }

        isCreatingReminder = true
        errorMessage = nil
        actionMessage = nil

        do {
            let result = try await reminderCreator.createReminder(makeReminderRequest())
            applyReminderResult(result)
            try await persistIfNeeded()
            didCreateReminder = true
            actionMessage = "Mock reminder created."
        } catch {
            errorMessage = "Unable to create reminder for this card."
        }

        isCreatingReminder = false
    }

    func createCalendarEvent() async {
        guard case .calendar(let calendar) = card else {
            errorMessage = "This card type does not support calendar events."
            return
        }

        isCreatingCalendar = true
        errorMessage = nil
        actionMessage = nil

        do {
            let result = try await calendarCreator.createCalendarEvent(CalendarCreationRequest(card: calendar))
            applyCalendarResult(result)
            try await persistIfNeeded()
            didCreateCalendar = true
            actionMessage = "Mock calendar event created."
        } catch {
            errorMessage = "Unable to create calendar event for this card."
        }

        isCreatingCalendar = false
    }

    func updateReminderTitle(_ value: String) {
        guard case .reminder(var reminder) = card else { return }
        reminder.title = value
        touch(&reminder.metadata)
        card = .reminder(reminder)
    }

    func updateReminderNotes(_ value: String) {
        guard case .reminder(var reminder) = card else { return }
        reminder.notes = value
        touch(&reminder.metadata)
        card = .reminder(reminder)
    }

    func updateReminderLocation(_ value: String) {
        guard case .reminder(var reminder) = card else { return }
        reminder.location = optionalString(value)
        touch(&reminder.metadata)
        card = .reminder(reminder)
    }

    func updateReminderDueDate(_ value: Date) {
        guard case .reminder(var reminder) = card else { return }
        reminder.dueDate = value
        touch(&reminder.metadata)
        card = .reminder(reminder)
    }

    func updateReminderPriority(_ value: ReminderCard.Priority) {
        guard case .reminder(var reminder) = card else { return }
        reminder.priority = value
        touch(&reminder.metadata)
        card = .reminder(reminder)
    }

    func updateCalendarTitle(_ value: String) {
        guard case .calendar(var calendar) = card else { return }
        calendar.title = value
        touch(&calendar.metadata)
        card = .calendar(calendar)
    }

    func updateCalendarStartDate(_ value: Date) {
        guard case .calendar(var calendar) = card else { return }
        calendar.startDate = value
        if calendar.endDate <= value {
            calendar.endDate = value.addingTimeInterval(3600)
        }
        touch(&calendar.metadata)
        card = .calendar(calendar)
    }

    func updateCalendarEndDate(_ value: Date) {
        guard case .calendar(var calendar) = card else { return }
        calendar.endDate = value
        touch(&calendar.metadata)
        card = .calendar(calendar)
    }

    func updateCalendarLocation(_ value: String) {
        guard case .calendar(var calendar) = card else { return }
        calendar.location = optionalString(value)
        touch(&calendar.metadata)
        card = .calendar(calendar)
    }

    func updateCalendarNotes(_ value: String) {
        guard case .calendar(var calendar) = card else { return }
        calendar.notes = value
        touch(&calendar.metadata)
        card = .calendar(calendar)
    }

    func updateNoteTitle(_ value: String) {
        guard case .note(var note) = card else { return }
        note.title = value
        touch(&note.metadata)
        card = .note(note)
    }

    func updateNoteSummary(_ value: String) {
        guard case .note(var note) = card else { return }
        note.summary = value
        touch(&note.metadata)
        card = .note(note)
    }

    func updateNoteBullets(_ value: String) {
        guard case .note(var note) = card else { return }
        note.bullets = lines(from: value)
        touch(&note.metadata)
        card = .note(note)
    }

    func updateNoteTodos(_ value: String) {
        guard case .note(var note) = card else { return }
        note.todos = lines(from: value)
        touch(&note.metadata)
        card = .note(note)
    }

    func updateShoppingProductName(_ value: String) {
        guard case .shopping(var shopping) = card else { return }
        shopping.productName = value
        touch(&shopping.metadata)
        card = .shopping(shopping)
    }

    func updateShoppingPrice(_ value: String) {
        guard case .shopping(var shopping) = card else { return }
        shopping.price = optionalString(value)
        touch(&shopping.metadata)
        card = .shopping(shopping)
    }

    func updateShoppingMerchant(_ value: String) {
        guard case .shopping(var shopping) = card else { return }
        shopping.merchant = optionalString(value)
        touch(&shopping.metadata)
        card = .shopping(shopping)
    }

    func updateShoppingOffer(_ value: String) {
        guard case .shopping(var shopping) = card else { return }
        shopping.offer = optionalString(value)
        touch(&shopping.metadata)
        card = .shopping(shopping)
    }

    func updateShoppingReminderDate(_ value: Date) {
        guard case .shopping(var shopping) = card else { return }
        shopping.reminderDate = value
        touch(&shopping.metadata)
        card = .shopping(shopping)
    }

    func updateShoppingNotes(_ value: String) {
        guard case .shopping(var shopping) = card else { return }
        shopping.notes = value
        touch(&shopping.metadata)
        card = .shopping(shopping)
    }

    func updateJobCompany(_ value: String) {
        guard case .job(var job) = card else { return }
        job.company = value
        touch(&job.metadata)
        card = .job(job)
    }

    func updateJobRole(_ value: String) {
        guard case .job(var job) = card else { return }
        job.role = value
        touch(&job.metadata)
        card = .job(job)
    }

    func updateJobSkills(_ value: String) {
        guard case .job(var job) = card else { return }
        job.skills = lines(from: value)
        touch(&job.metadata)
        card = .job(job)
    }

    func updateJobContact(_ value: String) {
        guard case .job(var job) = card else { return }
        job.contact = optionalString(value)
        touch(&job.metadata)
        card = .job(job)
    }

    func updateJobNextAction(_ value: String) {
        guard case .job(var job) = card else { return }
        job.nextAction = value
        touch(&job.metadata)
        card = .job(job)
    }

    func updateJobFollowUpDate(_ value: Date) {
        guard case .job(var job) = card else { return }
        job.followUpDate = value
        touch(&job.metadata)
        card = .job(job)
    }

    func updateJobNotes(_ value: String) {
        guard case .job(var job) = card else { return }
        job.notes = value
        touch(&job.metadata)
        card = .job(job)
    }

    private func makeReminderRequest() -> ReminderCreationRequest {
        switch card {
        case .reminder(let reminder):
            return ReminderCreationRequest(card: reminder)
        case .shopping(let shopping):
            return ReminderCreationRequest(
                sourceCardID: shopping.id,
                title: "Buy \(shopping.productName)",
                notes: shopping.notes,
                dueDate: shopping.reminderDate,
                location: shopping.merchant,
                priority: .medium
            )
        case .job(let job):
            return ReminderCreationRequest(
                sourceCardID: job.id,
                title: job.nextAction,
                notes: job.notes,
                dueDate: job.followUpDate,
                location: job.company,
                priority: .medium
            )
        case .calendar, .note:
            return ReminderCreationRequest(title: "")
        }
    }

    private func applyReminderResult(_ result: ExternalActionResult) {
        switch card {
        case .reminder(var reminder):
            reminder.reminderExternalID = result.externalID
            markCompleted(&reminder.metadata)
            card = .reminder(reminder)
        case .shopping(var shopping):
            shopping.reminderExternalID = result.externalID
            markCompleted(&shopping.metadata)
            card = .shopping(shopping)
        case .job(var job):
            job.reminderExternalID = result.externalID
            markCompleted(&job.metadata)
            card = .job(job)
        case .calendar, .note:
            break
        }
    }

    private func applyCalendarResult(_ result: ExternalActionResult) {
        guard case .calendar(var calendar) = card else { return }
        calendar.calendarExternalID = result.externalID
        markCompleted(&calendar.metadata)
        card = .calendar(calendar)
    }

    private func persistIfNeeded() async throws {
        guard didSave else { return }
        card = try await cardRepository.update(card)
    }

    private func touch(_ metadata: inout CardMetadata) {
        metadata.updatedAt = .now
    }

    private func markCompleted(_ metadata: inout CardMetadata) {
        metadata.status = .completed
        metadata.updatedAt = .now
    }

    private func optionalString(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func lines(from value: String) -> [String] {
        value
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
