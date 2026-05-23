import Foundation

enum GeneratedActionCardFactory {
    static func makeActionCard(
        from content: GeneratedInsightCard,
        context: VisionUnderstandingContext
    ) -> ActionCard {
        let baseCard = MockCardGenerator.placeholderCard(from: context, insight: content)
        let summary = content.summary ?? content.sections.first?.content ?? context.sceneSummary

        switch baseCard {
        case .note(var note):
            note.title = content.title
            note.summary = summary
            note.bullets = content.sections
                .filter { $0.kind == .checklist || $0.kind == .suggestedActions }
                .map(\.title)
            note.metadata.updatedAt = .now
            return .note(note)
        case .reminder(var reminder):
            reminder.title = content.title
            reminder.notes = summary
            reminder.location = context.entityValues(for: .location).first
            reminder.dueDate = context.firstDetectedDate
            reminder.metadata.updatedAt = .now
            return .reminder(reminder)
        case .calendar(var calendar):
            let startDate = context.firstDetectedDate ?? calendar.startDate
            calendar.title = content.title
            calendar.startDate = startDate
            calendar.endDate = max(calendar.endDate, startDate.addingTimeInterval(60 * 60))
            calendar.location = context.entityValues(for: .location).first
            calendar.notes = summary
            calendar.metadata.updatedAt = .now
            return .calendar(calendar)
        case .shopping(var shopping):
            shopping.productName = content.title
            shopping.price = context.entityValues(for: .price).first
            shopping.merchant = context.entityValues(for: .store).first
            shopping.offer = context.entityValues(for: .promotion).first
            shopping.notes = summary
            shopping.metadata.updatedAt = .now
            return .shopping(shopping)
        case .job(var job):
            job.company = context.entityValues(for: .company).first ?? job.company
            job.role = content.title
            job.skills = context.entityValues(for: .skill)
            job.contact = context.entityValues(for: .contact).first
            job.detail = summary
            job.notes = summary
            job.date = context.firstDetectedDate
            job.metadata.updatedAt = .now
            return .job(job)
        }
    }
}
