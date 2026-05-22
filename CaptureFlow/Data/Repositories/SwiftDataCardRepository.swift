import Foundation
import SwiftData

@ModelActor
actor SwiftDataCardRepository: CardRepository {
    func fetchCards(includeArchived: Bool) async throws -> [SavedInsightCard] {
        let records = try modelContext.fetch(cardsDescriptor(includeArchived: includeArchived))
        return try records.map { try $0.decodedCard() }
    }

    func fetchRecentCards(limit: Int, includeArchived: Bool) async throws -> [SavedInsightCard] {
        guard limit > 0 else { return [] }

        var descriptor = cardsDescriptor(includeArchived: includeArchived)
        descriptor.fetchLimit = limit

        let records = try modelContext.fetch(descriptor)
        return try records.map { try $0.decodedCard() }
    }

    func fetchCard(id: UUID) async throws -> SavedInsightCard? {
        try fetchRecord(id: id)?.decodedCard()
    }

    @discardableResult
    func save(_ card: SavedInsightCard) async throws -> SavedInsightCard {
        let savedCard = card.updatingStatus(.saved)

        if let record = try fetchRecord(id: savedCard.id) {
            try record.apply(savedCard)
        } else {
            let record = try SwiftDataSavedInsightCard(card: savedCard)
            modelContext.insert(record)
        }

        try modelContext.save()
        return savedCard
    }

    @discardableResult
    func update(_ card: SavedInsightCard) async throws -> SavedInsightCard {
        guard let record = try fetchRecord(id: card.id) else {
            throw RepositoryError.cardNotFound(card.id)
        }

        let updatedCard = card.updatingMetadata { metadata in
            metadata.updatedAt = .now
        }
        try record.apply(updatedCard)
        try modelContext.save()
        return updatedCard
    }

    @discardableResult
    func archiveCard(id: UUID) async throws -> SavedInsightCard {
        guard let record = try fetchRecord(id: id) else {
            throw RepositoryError.cardNotFound(id)
        }

        let archivedCard = try record.decodedCard().updatingStatus(.archived)
        try record.apply(archivedCard)
        try modelContext.save()
        return archivedCard
    }

    func deleteCard(id: UUID) async throws {
        guard let record = try fetchRecord(id: id) else {
            throw RepositoryError.cardNotFound(id)
        }

        modelContext.delete(record)
        try modelContext.save()
    }

    func reset() async throws {
        try modelContext.delete(model: SwiftDataSavedInsightCard.self)
        try modelContext.save()
    }

    private func fetchRecord(id: UUID) throws -> SwiftDataSavedInsightCard? {
        var descriptor = FetchDescriptor<SwiftDataSavedInsightCard>(
            predicate: #Predicate { record in
                record.id == id
            }
        )
        descriptor.fetchLimit = 1

        return try modelContext.fetch(descriptor).first
    }

    private func cardsDescriptor(includeArchived: Bool) -> FetchDescriptor<SwiftDataSavedInsightCard> {
        let sortBy = [
            SortDescriptor(\SwiftDataSavedInsightCard.updatedAt, order: .reverse),
            SortDescriptor(\SwiftDataSavedInsightCard.createdAt, order: .reverse)
        ]

        guard !includeArchived else {
            return FetchDescriptor(sortBy: sortBy)
        }

        let archivedStatus = CardStatus.archived.rawValue
        return FetchDescriptor(
            predicate: #Predicate { record in
                record.statusRawValue != archivedStatus
            },
            sortBy: sortBy
        )
    }
}
