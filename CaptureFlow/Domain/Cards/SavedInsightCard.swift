import Foundation

struct SavedInsightCard: Codable, Hashable, Identifiable, Sendable {
    var metadata: CardMetadata
    var insight: GeneratedInsightCard
    var actionCard: ActionCard?
    var reminderExternalID: String?
    var calendarExternalID: String?

    nonisolated var id: UUID { metadata.id }
    nonisolated var title: String { insight.title }
    nonisolated var createdAt: Date { metadata.createdAt }
    nonisolated var updatedAt: Date { metadata.updatedAt }
    nonisolated var sourceImage: CardSourceImage? { metadata.sourceImage }
    nonisolated var status: CardStatus { metadata.status }

    init(
        metadata: CardMetadata,
        insight: GeneratedInsightCard,
        actionCard: ActionCard? = nil,
        reminderExternalID: String? = nil,
        calendarExternalID: String? = nil
    ) {
        self.metadata = metadata
        self.insight = insight
        self.actionCard = actionCard
        self.reminderExternalID = reminderExternalID
        self.calendarExternalID = calendarExternalID
    }

    init(
        insight: GeneratedInsightCard,
        actionCard: ActionCard?
    ) {
        let adapterMetadata = actionCard?.metadata
        self.init(
            metadata: CardMetadata(
                id: adapterMetadata?.id ?? insight.id,
                createdAt: adapterMetadata?.createdAt ?? .now,
                updatedAt: adapterMetadata?.updatedAt ?? .now,
                sourceImage: adapterMetadata?.sourceImage,
                confidence: adapterMetadata?.confidence ?? ConfidenceLevel.from(score: insight.confidence),
                confidenceScore: adapterMetadata?.confidenceScore ?? insight.confidence,
                status: adapterMetadata?.status ?? .pending
            ),
            insight: insight,
            actionCard: actionCard
        )
    }

    nonisolated var markdown: String {
        insight.markdown
    }

    nonisolated var reminderRequest: ReminderCreationRequest? {
        guard reminderExternalID == nil else {
            return nil
        }

        return actionCard?.reminderRequestForCardResult()
    }

    nonisolated var calendarRequest: CalendarCreationRequest? {
        guard calendarExternalID == nil,
              case .calendar(let calendar) = actionCard
        else {
            return nil
        }

        return CalendarCreationRequest(card: calendar)
    }

    nonisolated var supportsReminderAction: Bool {
        reminderRequest != nil || reminderExternalID != nil
    }

    nonisolated var supportsCalendarAction: Bool {
        calendarRequest != nil || calendarExternalID != nil
    }

    nonisolated func updatingMetadata(_ transform: (inout CardMetadata) -> Void) -> SavedInsightCard {
        var copy = self
        transform(&copy.metadata)
        copy.actionCard = copy.actionCard?.updatingMetadata(transform)
        return copy
    }

    nonisolated func updatingStatus(_ status: CardStatus, updatedAt: Date = .now) -> SavedInsightCard {
        var copy = self
        copy.metadata.status = status
        copy.metadata.updatedAt = updatedAt
        copy.actionCard = copy.actionCard?.updatingStatus(status, updatedAt: updatedAt)
        return copy
    }

    nonisolated func applyingReminderResult(_ result: ExternalActionResult) -> SavedInsightCard {
        var copy = self
        copy.reminderExternalID = result.externalID
        copy.metadata.status = .completed
        copy.metadata.updatedAt = .now
        copy.actionCard = copy.actionCard?.applyingReminderResult(result)
        return copy
    }

    nonisolated func applyingCalendarResult(_ result: ExternalActionResult) -> SavedInsightCard {
        var copy = self
        copy.calendarExternalID = result.externalID
        copy.metadata.status = .completed
        copy.metadata.updatedAt = .now
        copy.actionCard = copy.actionCard?.applyingCalendarResult(result)
        return copy
    }
}
