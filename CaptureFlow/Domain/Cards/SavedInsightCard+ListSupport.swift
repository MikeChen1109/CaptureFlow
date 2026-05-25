import Foundation

extension SavedInsightCard {
    var inboxFilterType: CardType {
        let cardType = actionCard?.type ?? metadata.cardType ?? .unknown
        return cardType == .unknown ? .other : cardType
    }

    var searchableText: String {
        [
            title,
            insight.summary,
            actionCard?.title,
            insight.sections.map(\.title).joined(separator: " "),
            insight.sections.map(\.content).joined(separator: " ")
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }

    func isExpired(relativeTo date: Date) -> Bool {
        guard let expirationDate else {
            return false
        }

        return expirationDate < date
    }

    private var expirationDate: Date? {
        switch actionCard {
        case .calendar(let card):
            card.endDate
        case .reminder(let card):
            card.dueDate
        case .shopping(let card):
            card.date
        case .job(let card):
            card.date
        case .note, .none:
            nil
        }
    }
}

extension CardType {
    static let inboxFilterCategories: [CardType] = allCases.filter { $0 != .unknown }
}

extension Array where Element == SavedInsightCard {
    func sortedByCreatedDate() -> [SavedInsightCard] {
        sorted { first, second in
            if first.createdAt == second.createdAt {
                return first.updatedAt > second.updatedAt
            }

            return first.createdAt > second.createdAt
        }
    }

    func recentlyCreated(limit: Int) -> [SavedInsightCard] {
        Array(sortedByCreatedDate().prefix(Swift.max(limit, 0)))
    }
}
