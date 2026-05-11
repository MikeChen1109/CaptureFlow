import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var cards: [ActionCard] = []
    @Published private(set) var creditBalance: CreditBalance?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let cardRepository: any CardRepository
    private let creditProvider: any CreditProviding
    private var didCompleteInitialLoad: Bool

    init(
        cardRepository: any CardRepository,
        creditProvider: any CreditProviding
    ) {
        self.cardRepository = cardRepository
        self.creditProvider = creditProvider
        self.didCompleteInitialLoad = false
    }

    convenience init(container: AppContainer) {
        self.init(
            cardRepository: container.cardRepository,
            creditProvider: container.creditProvider
        )
    }

    func loadIfNeeded() async {
        guard !didCompleteInitialLoad else {
            return
        }

        await load(force: false)
    }

    func load(force: Bool = true) async {
        guard !isLoading else {
            return
        }
        guard force || !didCompleteInitialLoad else {
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            async let cards = cardRepository.fetchRecentCards(limit: 20)
            async let balance = creditProvider.currentBalance()

            self.cards = try await cards
            self.creditBalance = try await balance
            didCompleteInitialLoad = true
        } catch {
            errorMessage = "Unable to load inbox."
        }

        isLoading = false
    }

    func refresh() async {
        await load(force: true)
    }
}
