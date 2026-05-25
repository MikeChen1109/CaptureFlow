import Foundation
import Testing
@testable import CaptureFlow

@MainActor
struct InboxViewModelTests {
    @Test func allFilterShowsAllNonArchivedCards() async {
        let shoppingCard = makeSavedCard(
            type: .shopping,
            title: "Desk lamp",
            createdAt: Date(timeIntervalSince1970: 3)
        )
        let jobCard = makeSavedCard(
            type: .job,
            title: "Product role",
            createdAt: Date(timeIntervalSince1970: 2)
        )
        let archivedShoppingCard = makeSavedCard(
            type: .shopping,
            title: "Old chair",
            status: .archived,
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let viewModel = InboxViewModel(
            cardRepository: InMemoryCardRepository(seedCards: [
                shoppingCard,
                jobCard,
                archivedShoppingCard
            ])
        )

        await viewModel.loadIfNeeded()

        #expect(viewModel.selectedFilter == .all)
        #expect(viewModel.filteredCards.map(\.id) == [
            shoppingCard.id,
            jobCard.id
        ])
    }

    @Test func categoryFilterShowsMatchingNonArchivedCards() async {
        let shoppingCard = makeSavedCard(
            type: .shopping,
            title: "Desk lamp",
            createdAt: Date(timeIntervalSince1970: 3)
        )
        let jobCard = makeSavedCard(
            type: .job,
            title: "Product role",
            createdAt: Date(timeIntervalSince1970: 2)
        )
        let archivedShoppingCard = makeSavedCard(
            type: .shopping,
            title: "Old chair",
            status: .archived,
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let viewModel = InboxViewModel(
            cardRepository: InMemoryCardRepository(seedCards: [
                shoppingCard,
                jobCard,
                archivedShoppingCard
            ])
        )

        await viewModel.loadIfNeeded()
        viewModel.selectedFilter = .category(.shopping)

        #expect(viewModel.filteredCards.map(\.id) == [shoppingCard.id])
    }

    @Test func archivedFilterShowsArchivedCardsAcrossCategories() async {
        let archivedShoppingCard = makeSavedCard(
            type: .shopping,
            title: "Archived offer",
            status: .archived,
            createdAt: Date(timeIntervalSince1970: 2)
        )
        let archivedJobCard = makeSavedCard(
            type: .job,
            title: "Archived role",
            status: .archived,
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let activeJobCard = makeSavedCard(
            type: .job,
            title: "Open role",
            createdAt: Date(timeIntervalSince1970: 3)
        )
        let viewModel = InboxViewModel(
            cardRepository: InMemoryCardRepository(seedCards: [
                archivedShoppingCard,
                archivedJobCard,
                activeJobCard
            ])
        )

        await viewModel.loadIfNeeded()
        viewModel.selectedFilter = .archived

        #expect(viewModel.filteredCards.map(\.id) == [
            archivedShoppingCard.id,
            archivedJobCard.id
        ])
    }

    @Test func unknownCardsAppearInOtherCategory() async {
        let unknownCard = makeSavedCard(
            type: .unknown,
            title: "Unclear screenshot"
        )
        let viewModel = InboxViewModel(
            cardRepository: InMemoryCardRepository(seedCards: [unknownCard])
        )

        await viewModel.loadIfNeeded()
        viewModel.selectedFilter = .category(.other)

        #expect(viewModel.filteredCards.map(\.id) == [unknownCard.id])
    }
}

private func makeSavedCard(
    type: CardType,
    title: String,
    status: CardStatus = .saved,
    createdAt: Date = Date(timeIntervalSince1970: 1)
) -> SavedInsightCard {
    let metadata = CardMetadata(
        id: UUID(),
        createdAt: createdAt,
        updatedAt: createdAt,
        cardType: type,
        confidence: .high,
        confidenceScore: 0.9,
        status: status
    )
    let insight = GeneratedInsightCard(
        id: metadata.id,
        title: title,
        usefulness: .useful,
        confidence: 0.9,
        summary: nil,
        sections: []
    )

    return SavedInsightCard(
        insight: insight,
        actionCard: makeActionCard(type: type, title: title, metadata: metadata)
    )
}

private func makeActionCard(type: CardType, title: String, metadata: CardMetadata) -> ActionCard {
    switch type {
    case .shopping, .food, .receipt, .product, .promotion:
        .shopping(
            ShoppingCard(
                metadata: metadata,
                productName: title
            )
        )
    case .job:
        .job(
            JobCard(
                metadata: metadata,
                company: "Example",
                role: title,
                detail: title
            )
        )
    default:
        .note(
            NoteCard(
                metadata: metadata,
                title: title,
                summary: title
            )
        )
    }
}
