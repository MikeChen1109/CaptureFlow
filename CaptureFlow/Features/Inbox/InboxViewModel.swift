import Combine
import Foundation

@MainActor
final class InboxViewModel: ObservableObject {
    @Published private(set) var cards: [SavedInsightCard] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published var selectedStatusFilter: InboxStatusFilter = .active
    @Published var searchText = "" {
        didSet {
            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                debouncedSearchText = ""
            }
        }
    }
    @Published var errorMessage: String?

    @Published private var debouncedSearchText = ""

    private let cardRepository: any CardRepository
    private let nowProvider: () -> Date
    private var cancellables: Set<AnyCancellable> = []

    init(
        cardRepository: any CardRepository,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.cardRepository = cardRepository
        self.nowProvider = nowProvider
        bindSearchText()
    }

    convenience init(container: AppContainer) {
        self.init(cardRepository: container.cardRepository)
    }

    var filteredCards: [SavedInsightCard] {
        if hasActiveSearch {
            return cards
                .filter { matchesSearch($0, query: normalizedSearchText) }
                .sortedByCreatedDate()
        }

        return cards
            .filter(matchesStatusFilter)
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
        debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasActiveSearch: Bool {
        !normalizedSearchText.isEmpty
    }

    private func bindSearchText() {
        $searchText
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .removeDuplicates()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] searchText in
                self?.debouncedSearchText = searchText
            }
            .store(in: &cancellables)
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

    private func matchesSearch(_ card: SavedInsightCard, query: String) -> Bool {
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
