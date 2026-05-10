import Combine
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var creditBalance: CreditBalance?
    @Published private(set) var isLoading = false
    @Published private(set) var isResetting = false
    @Published var errorMessage: String?
    @Published var actionMessage: String?

    private let cardRepository: any CardRepository
    private let creditProvider: any CreditProviding

    init(
        cardRepository: any CardRepository,
        creditProvider: any CreditProviding
    ) {
        self.cardRepository = cardRepository
        self.creditProvider = creditProvider
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            creditBalance = try await creditProvider.currentBalance()
        } catch {
            errorMessage = "Unable to load prototype info."
        }

        isLoading = false
    }

    func resetPrototypeData() async {
        isResetting = true
        errorMessage = nil
        actionMessage = nil

        do {
            try await cardRepository.reset()
            creditBalance = try await creditProvider.resetCredits()
            actionMessage = "Local prototype data reset."
        } catch {
            errorMessage = "Unable to reset local data."
        }

        isResetting = false
    }
}
