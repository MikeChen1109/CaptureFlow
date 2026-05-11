import Foundation

protocol CardGenerating: Sendable {
    func generateContent(from context: VisionUnderstandingContext) async throws -> GeneratedCardContent
    func generateCard(from context: VisionUnderstandingContext) async throws -> ActionCard
    func streamCard(from context: VisionUnderstandingContext) -> AsyncThrowingStream<CardGenerationEvent, Error>
}

enum CardGenerationEvent: Sendable {
    case partial(CardGenerationPartial)
    case completed(ActionCard)
}

struct CardGenerationPartial: Equatable, Sendable {
    var title: String?
    var summary: String?
}

extension CardGenerating {
    func streamCard(from context: VisionUnderstandingContext) -> AsyncThrowingStream<CardGenerationEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let card = try await generateCard(from: context)
                    continuation.yield(.partial(card.generationPartial))
                    continuation.yield(.completed(card))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

extension ActionCard {
    var generationPartial: CardGenerationPartial {
        CardGenerationPartial(
            title: title,
            summary: generationSummary
        )
    }

    private var generationSummary: String {
        switch self {
        case .reminder(let reminder):
            [
                "This image was turned into a reminder for \(reminder.title).",
                reminder.dueDate.map { "Target date: \($0.formatted(date: .abbreviated, time: .shortened))." },
                reminder.location.map { "Location: \($0)." }
            ]
            .compactMap { $0 }
            .joined(separator: " ")
        case .calendar(let calendar):
            [
                "This looks like a calendar event: \(calendar.title).",
                "Scheduled from \(calendar.startDate.formatted(date: .abbreviated, time: .shortened)) to \(calendar.endDate.formatted(date: .abbreviated, time: .shortened)).",
                calendar.location.map { "Location: \($0)." }
            ]
            .compactMap { $0 }
            .joined(separator: " ")
        case .note(let note):
            note.summary.isEmpty ? "This image was converted into a structured note." : note.summary
        case .shopping(let shopping):
            [
                "This image was recognized as a shopping item: \(shopping.productName).",
                shopping.price.map { "Detected price: \($0)." },
                shopping.merchant.map { "Merchant: \($0)." },
                shopping.offer.map { "Offer: \($0)." }
            ]
            .compactMap { $0 }
            .joined(separator: " ")
        case .job(let job):
            [
                "This image was converted into a job lead for \(job.role) at \(job.company).",
                job.detail.isEmpty ? nil : job.detail,
                job.date.map { "Follow-up date: \($0.formatted(date: .abbreviated, time: .shortened))." }
            ]
            .compactMap { $0 }
            .joined(separator: " ")
        }
    }
}
