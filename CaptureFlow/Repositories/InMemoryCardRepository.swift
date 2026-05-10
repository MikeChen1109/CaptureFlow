import Foundation

actor InMemoryCardRepository: CardRepository {
    private var cardsByID: [UUID: ActionCard]

    init(seedCards: [ActionCard] = []) {
        self.cardsByID = Dictionary(
            uniqueKeysWithValues: seedCards.map { ($0.id, $0) }
        )
    }

    func fetchCards(includeArchived: Bool) async throws -> [ActionCard] {
        sortedCards(includeArchived: includeArchived)
    }

    func fetchRecentCards(limit: Int, includeArchived: Bool) async throws -> [ActionCard] {
        Array(sortedCards(includeArchived: includeArchived).prefix(max(limit, 0)))
    }

    func fetchCard(id: UUID) async throws -> ActionCard? {
        cardsByID[id]
    }

    @discardableResult
    func save(_ card: ActionCard) async throws -> ActionCard {
        let savedCard = card.updatingStatus(.saved)
        cardsByID[savedCard.id] = savedCard
        return savedCard
    }

    @discardableResult
    func update(_ card: ActionCard) async throws -> ActionCard {
        guard cardsByID[card.id] != nil else {
            throw RepositoryError.cardNotFound(card.id)
        }

        let updatedCard = card.updatingMetadata { metadata in
            metadata.updatedAt = .now
        }
        cardsByID[updatedCard.id] = updatedCard
        return updatedCard
    }

    @discardableResult
    func archiveCard(id: UUID) async throws -> ActionCard {
        guard let card = cardsByID[id] else {
            throw RepositoryError.cardNotFound(id)
        }

        let archivedCard = card.updatingStatus(.archived)
        cardsByID[id] = archivedCard
        return archivedCard
    }

    func deleteCard(id: UUID) async throws {
        guard cardsByID.removeValue(forKey: id) != nil else {
            throw RepositoryError.cardNotFound(id)
        }
    }

    func reset() async throws {
        cardsByID.removeAll()
    }

    private func sortedCards(includeArchived: Bool) -> [ActionCard] {
        cardsByID.values
            .filter { includeArchived || $0.status != .archived }
            .sorted { first, second in
                if first.updatedAt == second.updatedAt {
                    return first.createdAt > second.createdAt
                }

                return first.updatedAt > second.updatedAt
            }
    }
}
