import Combine
import Foundation

@MainActor
final class InboxViewModel: ObservableObject {
    @Published private(set) var cards: [SavedInsightCard] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published var selectedStatusFilter: InboxStatusFilter = .active
    @Published var searchText = ""
    @Published var errorMessage: String?

    private let cardRepository: any CardRepository
    private let nowProvider: () -> Date

    init(
        cardRepository: any CardRepository,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.cardRepository = cardRepository
        self.nowProvider = nowProvider
    }

    convenience init(container: AppContainer) {
        self.init(cardRepository: container.cardRepository)
    }

    var filteredCards: [SavedInsightCard] {
        cards
            .filter(matchesStatusFilter)
            .filter(matchesSearch)
            .sortedByCreatedDate()
    }

    var emptyStateTitle: String {
        if hasActiveSearch {
            return "No matching insights"
        }

        return switch selectedStatusFilter {
        case .active:
            "No active insights"
        case .expired:
            "No expired insights"
        case .archived:
            "No archived insights"
        }
    }

    var emptyStateMessage: String {
        if hasActiveSearch {
            return "Try a different search or clear the search field."
        }

        return switch selectedStatusFilter {
        case .active:
            "New saved insights and unfinished cards will appear here."
        case .expired:
            "Insights with past due dates or ended events will appear here."
        case .archived:
            "Archived insights will appear here after you move them out of the active inbox."
        }
    }

    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasActiveSearch: Bool {
        !normalizedSearchText.isEmpty
    }

    func loadIfNeeded() async {
        guard !hasLoaded else {
            return
        }

        await load()
    }

    func refresh() async {
        await load()
    }

    func applyUpdatedCard(_ card: SavedInsightCard) {
        if let index = cards.firstIndex(where: { $0.id == card.id }) {
            cards[index] = card
        } else {
            cards.insert(card, at: 0)
        }

        cards = cards.sortedByCreatedDate()
    }

    func removeCardLocally(_ cardID: UUID) {
        cards.removeAll { $0.id == cardID }
    }

    private func load() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            cards = try await cardRepository.fetchCards(includeArchived: true)
                .sortedByCreatedDate()
            hasLoaded = true
        } catch {
            errorMessage = "Unable to load inbox."
        }

        isLoading = false
    }

    private func matchesStatusFilter(_ card: SavedInsightCard) -> Bool {
        switch selectedStatusFilter {
        case .active:
            card.status != .archived && !card.isExpired(relativeTo: nowProvider())
        case .expired:
            card.status != .archived && card.isExpired(relativeTo: nowProvider())
        case .archived:
            card.status == .archived
        }
    }

    private func matchesSearch(_ card: SavedInsightCard) -> Bool {
        let query = normalizedSearchText
        guard !query.isEmpty else {
            return true
        }

        return card.searchableText.localizedCaseInsensitiveContains(query)
    }
}

enum InboxStatusFilter: String, CaseIterable, Identifiable {
    case active
    case expired
    case archived

    var id: String { rawValue }

    var title: String {
        switch self {
        case .active:
            "Active"
        case .expired:
            "Expired"
        case .archived:
            "Archived"
        }
    }
}

private extension SavedInsightCard {
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

    var expirationDate: Date? {
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

private extension Array where Element == SavedInsightCard {
    func sortedByCreatedDate() -> [SavedInsightCard] {
        sorted { first, second in
            if first.createdAt == second.createdAt {
                return first.updatedAt > second.updatedAt
            }

            return first.createdAt > second.createdAt
        }
    }
}
