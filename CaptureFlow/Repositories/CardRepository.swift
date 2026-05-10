import Foundation

protocol CardRepository: Sendable {
    func fetchCards(includeArchived: Bool) async throws -> [ActionCard]
    func fetchRecentCards(limit: Int, includeArchived: Bool) async throws -> [ActionCard]
    func fetchCard(id: UUID) async throws -> ActionCard?
    @discardableResult func save(_ card: ActionCard) async throws -> ActionCard
    @discardableResult func update(_ card: ActionCard) async throws -> ActionCard
    @discardableResult func archiveCard(id: UUID) async throws -> ActionCard
    func deleteCard(id: UUID) async throws
    func reset() async throws
}

extension CardRepository {
    func fetchCards() async throws -> [ActionCard] {
        try await fetchCards(includeArchived: false)
    }

    func fetchRecentCards(limit: Int) async throws -> [ActionCard] {
        try await fetchRecentCards(limit: limit, includeArchived: false)
    }
}
