import Combine
import Foundation

@MainActor
final class InboxViewModel: ObservableObject {
    @Published private(set) var cards: [SavedInsightCard] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published var selectedFilter: InboxFilter = .all
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
            .filter(matchesSelectedFilter)
            .sortedByCreatedDate()
    }

    var emptyStateTitle: String {
        if hasActiveSearch {
            return "No matching insights"
        }

        return switch selectedFilter {
        case .all:
            "No insights"
        case .category(let cardType):
            "No \(cardType.displayName.lowercased()) insights"
        case .archived:
            "No archived insights"
        }
    }

    var emptyStateMessage: String {
        if hasActiveSearch {
            return "Try a different search or clear the search field."
        }

        return switch selectedFilter {
        case .all:
            "Saved insights will appear here."
        case .category(let cardType):
            "Saved \(cardType.displayName.lowercased()) insights will appear here."
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

    private func matchesSelectedFilter(_ card: SavedInsightCard) -> Bool {
        switch selectedFilter {
        case .all:
            card.status != .archived
        case .category(let cardType):
            card.status != .archived && card.inboxFilterType == cardType
        case .archived:
            card.status == .archived
        }
    }

    private func matchesSearch(_ card: SavedInsightCard, query: String) -> Bool {
        return card.searchableText.localizedCaseInsensitiveContains(query)
    }
}

enum InboxFilter: Hashable, Identifiable {
    case all
    case category(CardType)
    case archived

    static let allCases: [InboxFilter] = [.all] + CardType.inboxFilterCategories.map(InboxFilter.category) + [.archived]

    var id: String {
        switch self {
        case .all:
            "all"
        case .category(let cardType):
            "category-\(cardType.rawValue)"
        case .archived:
            "archived"
        }
    }

    var title: String {
        switch self {
        case .all:
            "All"
        case .category(let cardType):
            cardType.displayName
        case .archived:
            "Archived"
        }
    }
}
