import Foundation

protocol CardRepository: Sendable {
    func fetchCards(includeArchived: Bool) async throws -> [SavedInsightCard]
    func fetchRecentCards(limit: Int, includeArchived: Bool) async throws -> [SavedInsightCard]
    func fetchCard(id: UUID) async throws -> SavedInsightCard?
    @discardableResult func save(_ card: SavedInsightCard) async throws -> SavedInsightCard
    @discardableResult func update(_ card: SavedInsightCard) async throws -> SavedInsightCard
    @discardableResult func archiveCard(id: UUID) async throws -> SavedInsightCard
    func deleteCard(id: UUID) async throws
    func reset() async throws
}

extension CardRepository {
    func fetchCards() async throws -> [SavedInsightCard] {
        try await fetchCards(includeArchived: false)
    }

    func fetchRecentCards(limit: Int) async throws -> [SavedInsightCard] {
        try await fetchRecentCards(limit: limit, includeArchived: false)
    }
}
