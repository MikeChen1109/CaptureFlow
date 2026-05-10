import Combine
import Foundation
import UIKit

@MainActor
final class CardDetailViewModel: ObservableObject {
    @Published private(set) var card: ActionCard?
    @Published private(set) var isLoading = false
    @Published private(set) var isArchiving = false
    @Published private(set) var isDeleting = false
    @Published private(set) var didCopyMarkdown = false
    @Published var errorMessage: String?
    @Published var actionMessage: String?

    private let cardID: UUID
    private let cardRepository: any CardRepository

    init(cardID: UUID, cardRepository: any CardRepository) {
        self.cardID = cardID
        self.cardRepository = cardRepository
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            card = try await cardRepository.fetchCard(id: cardID)
            if card == nil {
                errorMessage = "Card not found."
            }
        } catch {
            errorMessage = "Unable to load this card."
        }

        isLoading = false
    }

    func copyMarkdown() {
        guard let card else { return }
        UIPasteboard.general.string = card.markdown
        didCopyMarkdown = true
        actionMessage = "Markdown copied."
        errorMessage = nil
    }

    func archive() async -> Bool {
        isArchiving = true
        errorMessage = nil
        actionMessage = nil

        do {
            card = try await cardRepository.archiveCard(id: cardID)
            actionMessage = "Archived."
            isArchiving = false
            return true
        } catch {
            errorMessage = "Unable to archive this card."
            isArchiving = false
            return false
        }
    }

    func delete() async -> Bool {
        isDeleting = true
        errorMessage = nil
        actionMessage = nil

        do {
            try await cardRepository.deleteCard(id: cardID)
            card = nil
            actionMessage = "Deleted."
            isDeleting = false
            return true
        } catch {
            errorMessage = "Unable to delete this card."
            isDeleting = false
            return false
        }
    }
}
