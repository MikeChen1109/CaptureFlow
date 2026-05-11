import Combine
import Foundation
import UIKit

struct GeneratedSectionState: Identifiable, Equatable, Sendable {
    var id: GeneratedSectionType { sectionType }
    var sectionType: GeneratedSectionType
    var status: GeneratedSectionStatus
    var content: GeneratedSectionContent?
}

enum GeneratedSectionType: String, CaseIterable, Identifiable, Sendable {
    case summary
    case plan
    case recommendedActions
    case draft
    case keyDetails
    case missingInfo
    case personalNote

    var id: String { rawValue }
}

enum GeneratedSectionStatus: String, Sendable {
    case waiting
    case generating
    case completed
}

enum GeneratedSectionContent: Equatable, Sendable {
    case summary(String)
    case plan(title: String, steps: [GeneratedPlanStep])
    case recommendedActions([GeneratedAction])
    case draft(GeneratedDraft)
    case keyDetails([GeneratedField])
    case missingInfo([String])
    case personalNote(String)
}

@MainActor
final class CardResultViewModel: ObservableObject {
    @Published private(set) var card: ActionCard
    @Published private(set) var sectionStates: [GeneratedSectionState]
    @Published private(set) var isPartialGenerationComplete = false
    @Published private(set) var isSaving = false
    @Published private(set) var isCreatingReminder = false
    @Published private(set) var isCreatingCalendar = false
    @Published private(set) var didSave = false
    @Published private(set) var didCreateReminder = false
    @Published private(set) var didCreateCalendar = false
    @Published private(set) var didCopyMarkdown = false
    @Published private var localPersonalNote = ""
    @Published var errorMessage: String?
    @Published var actionMessage: String?

    let generatedContent: GeneratedCardContent
    private let cardRepository: any CardRepository
    private let reminderCreator: any ReminderCreating
    private let calendarCreator: any CalendarCreating
    private var generationTask: Task<Void, Never>?

    init(
        card: ActionCard,
        generatedContent: GeneratedCardContent,
        cardRepository: any CardRepository,
        reminderCreator: any ReminderCreating,
        calendarCreator: any CalendarCreating
    ) {
        self.card = card
        self.generatedContent = generatedContent
        self.sectionStates = Self.initialSectionStates()
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

    var personalNote: String {
        switch card {
        case .reminder(let reminder):
            reminder.notes
        case .calendar(let calendar):
            calendar.notes
        case .note:
            localPersonalNote
        case .shopping(let shopping):
            shopping.notes
        case .job(let job):
            job.notes
        }
    }

    func startPartialGeneration() {
        guard generationTask == nil, !isPartialGenerationComplete else {
            return
        }

        sectionStates = Self.initialSectionStates()
        generationTask = Task { [weak self] in
            await self?.runPartialGeneration()
        }
    }

    func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
    }

    func sectionState(for type: GeneratedSectionType) -> GeneratedSectionState {
        sectionStates.first { $0.sectionType == type }
            ?? GeneratedSectionState(sectionType: type, status: .waiting, content: nil)
    }

    func updatePersonalNote(_ value: String) {
        switch card {
        case .reminder:
            updateReminderNotes(value)
        case .calendar:
            updateCalendarNotes(value)
        case .note:
            localPersonalNote = value
        case .shopping:
            updateShoppingNotes(value)
        case .job:
            updateJobNotes(value)
        }
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

    func updateNoteItems(_ value: String) {
        guard case .note(var note) = card else { return }
        note.items = lines(from: value)
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

    func updateShoppingDate(_ value: Date) {
        guard case .shopping(var shopping) = card else { return }
        shopping.date = value
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

    func updateJobDetail(_ value: String) {
        guard case .job(var job) = card else { return }
        job.detail = value
        touch(&job.metadata)
        card = .job(job)
    }

    func updateJobDate(_ value: Date) {
        guard case .job(var job) = card else { return }
        job.date = value
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
                dueDate: shopping.date,
                location: shopping.merchant,
                priority: .medium
            )
        case .job(let job):
            return ReminderCreationRequest(
                sourceCardID: job.id,
                title: optionalString(job.detail) ?? "Review \(job.role) at \(job.company)",
                notes: job.notes,
                dueDate: job.date,
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

    private static func initialSectionStates() -> [GeneratedSectionState] {
        GeneratedSectionType.allCases.map {
            GeneratedSectionState(sectionType: $0, status: .waiting, content: nil)
        }
    }

    private func runPartialGeneration() async {
        isPartialGenerationComplete = false

        await revealSummary()
        await revealPlan()
        await revealRecommendedActions()
        await revealDraft()
        await revealKeyDetails()
        await revealMissingInfo()
        await revealPersonalNote()

        guard !Task.isCancelled else { return }
        isPartialGenerationComplete = true
        generationTask = nil
    }

    private func revealSummary() async {
        setSection(.summary, status: .generating, content: nil)
        await sleep(milliseconds: 420)
        setSection(.summary, status: .completed, content: .summary(generatedContent.summary))
        await sleep(milliseconds: 360)
    }

    private func revealPlan() async {
        setSection(
            .plan,
            status: .generating,
            content: .plan(title: generatedContent.planTitle, steps: [])
        )

        for index in generatedContent.planSteps.indices {
            guard !Task.isCancelled else { return }
            await sleep(milliseconds: 360)
            setSection(
                .plan,
                status: .generating,
                content: .plan(
                    title: generatedContent.planTitle,
                    steps: Array(generatedContent.planSteps.prefix(index + 1))
                )
            )
        }

        await sleep(milliseconds: 300)
        setSection(
            .plan,
            status: .completed,
            content: .plan(title: generatedContent.planTitle, steps: generatedContent.planSteps)
        )
        await sleep(milliseconds: 480)
    }

    private func revealRecommendedActions() async {
        setSection(.recommendedActions, status: .generating, content: .recommendedActions([]))

        for index in generatedContent.recommendedActions.indices {
            guard !Task.isCancelled else { return }
            await sleep(milliseconds: 330)
            setSection(
                .recommendedActions,
                status: .generating,
                content: .recommendedActions(Array(generatedContent.recommendedActions.prefix(index + 1)))
            )
        }

        await sleep(milliseconds: 300)
        setSection(
            .recommendedActions,
            status: .completed,
            content: .recommendedActions(generatedContent.recommendedActions)
        )
        await sleep(milliseconds: 520)
    }

    private func revealDraft() async {
        let fullDraft = generatedContent.draftOutput
        setSection(
            .draft,
            status: .generating,
            content: .draft(GeneratedDraft(type: fullDraft.type, title: fullDraft.title, body: ""))
        )

        var renderedBody = ""
        for token in draftTokens(from: fullDraft.body) {
            guard !Task.isCancelled else { return }
            renderedBody += token
            setSection(
                .draft,
                status: .generating,
                content: .draft(GeneratedDraft(type: fullDraft.type, title: fullDraft.title, body: renderedBody))
            )
            await sleep(milliseconds: token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 20 : 70)
        }

        await sleep(milliseconds: 320)
        setSection(.draft, status: .completed, content: .draft(fullDraft))
        await sleep(milliseconds: 440)
    }

    private func revealKeyDetails() async {
        setSection(.keyDetails, status: .generating, content: .keyDetails([]))

        for index in generatedContent.keyDetails.indices {
            guard !Task.isCancelled else { return }
            await sleep(milliseconds: 280)
            setSection(
                .keyDetails,
                status: .generating,
                content: .keyDetails(Array(generatedContent.keyDetails.prefix(index + 1)))
            )
        }

        await sleep(milliseconds: 300)
        setSection(.keyDetails, status: .completed, content: .keyDetails(generatedContent.keyDetails))
        await sleep(milliseconds: 460)
    }

    private func revealMissingInfo() async {
        setSection(.missingInfo, status: .generating, content: .missingInfo([]))

        for index in generatedContent.missingInfo.indices {
            guard !Task.isCancelled else { return }
            await sleep(milliseconds: 280)
            setSection(
                .missingInfo,
                status: .generating,
                content: .missingInfo(Array(generatedContent.missingInfo.prefix(index + 1)))
            )
        }

        await sleep(milliseconds: 300)
        setSection(.missingInfo, status: .completed, content: .missingInfo(generatedContent.missingInfo))
        await sleep(milliseconds: 380)
    }

    private func revealPersonalNote() async {
        setSection(.personalNote, status: .generating, content: nil)
        await sleep(milliseconds: 420)
        setSection(
            .personalNote,
            status: .completed,
            content: .personalNote(generatedContent.personalNotePlaceholder)
        )
    }

    private func setSection(
        _ type: GeneratedSectionType,
        status: GeneratedSectionStatus,
        content: GeneratedSectionContent?
    ) {
        guard !Task.isCancelled else {
            return
        }

        guard let index = sectionStates.firstIndex(where: { $0.sectionType == type }) else {
            return
        }

        sectionStates[index].status = status
        sectionStates[index].content = content
    }

    private func sleep(milliseconds: UInt64) async {
        try? await Task.sleep(for: .milliseconds(milliseconds))
    }

    private func draftTokens(from value: String) -> [String] {
        let words = value.split(separator: " ", omittingEmptySubsequences: false)
        guard !words.isEmpty else {
            return []
        }

        return words.enumerated().map { index, word in
            index == words.count - 1 ? String(word) : "\(word) "
        }
    }
}
