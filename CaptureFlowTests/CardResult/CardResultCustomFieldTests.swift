import Foundation
import SwiftData
import Testing
@testable import CaptureFlow

struct CardResultCustomFieldTests {
    @Test func cardTypeCasesStayWithinSupportedSet() {
        #expect(CardType.allCases.map(\.rawValue) == [
            "unknown",
            "shopping",
            "event",
            "note",
            "job",
            "travel",
            "food",
            "receipt",
            "article",
            "product",
            "reminder",
            "contact",
            "promotion",
            "document",
            "appScreen",
            "other"
        ])
    }

    @Test func cardTypeDecodesLegacyRawValues() throws {
        let decoder = JSONDecoder()

        let legacyAuto = try decoder.decode(CardType.self, from: Data(#""auto""#.utf8))
        let legacyCalendar = try decoder.decode(CardType.self, from: Data(#""calendar""#.utf8))
        let unsupported = try decoder.decode(CardType.self, from: Data(#""unsupported""#.utf8))

        #expect(legacyAuto == .unknown)
        #expect(legacyCalendar == .event)
        #expect(unsupported == .unknown)
    }

    @Test func visionAnalysisDTOMapsToContextWithLocalSourceImage() {
        let sourceImage = CardSourceImage(
            source: .photoLibrary,
            localPath: "SourceImages/example.jpg",
            assetLocalIdentifier: "asset-123"
        )
        let request = VisionAnalysisRequest(
            imageData: Data([0xFF, 0xD8, 0xFF]),
            sourceImage: sourceImage,
            selectedCardType: .unknown
        )
        let dto = VisionAnalysisDTO(
            resolvedCardType: .receipt,
            sceneTitle: "Lunch receipt",
            sceneSummary: "A receipt with a total amount.",
            entities: [
                VisionEntityDTO(type: "price", label: "Total", value: "NT$320", confidence: 0.91)
            ],
            possibleActions: [
                VisionActionHintDTO(title: "Save Receipt", description: "Keep the expense details.", actionType: "save")
            ],
            confidenceScore: 0.88
        )

        let context = dto.understandingContext(from: request)

        #expect(context.requestedCardType == .unknown)
        #expect(context.resolvedCardType == .receipt)
        #expect(context.sourceImage == sourceImage)
        #expect(context.entities.first?.type == .price)
        #expect(context.possibleActions.first?.actionType == .save)
    }

    @Test func resolverTrimsPlainTextValues() {
        let resolver = CardResultCustomFieldValueResolver()

        #expect(
            resolver.resolvedValue(
                for: .note,
                textValue: "  Follow up with finance  ",
                dateValue: Date()
            ) == "Follow up with finance"
        )
        #expect(
            resolver.resolvedValue(
                for: .note,
                textValue: "   ",
                dateValue: Date()
            ) == nil
        )
    }

    @Test func resolverNormalizesLinksWithoutScheme() {
        let resolver = CardResultCustomFieldValueResolver()

        #expect(
            resolver.resolvedValue(
                for: .link,
                textValue: "example.com/path",
                dateValue: Date()
            ) == "https://example.com/path"
        )
        #expect(resolver.validationMessage(for: .link, textValue: "example.com/path") == nil)
        #expect(resolver.validationMessage(for: .link, textValue: "   ") == "Enter a link to continue.")
    }

    @Test func savedInsightCardMarkdownIncludesCustomFieldsWithoutUsefulnessOrConfidence() {
        let card = noteSavedInsightCard(
            customFields: [
                CardResultCustomField(type: .location, value: "Taipei"),
                CardResultCustomField(type: .note, value: "Bring portfolio")
            ]
        )

        let markdown = card.markdown

        #expect(!markdown.contains("**Usefulness:**"))
        #expect(!markdown.contains("**Confidence:**"))
        #expect(markdown.contains("## Custom Fields"))
        #expect(markdown.contains("- **Location:** Taipei"))
        #expect(markdown.contains("- **Note:** Bring portfolio"))
    }

    @Test @MainActor func viewModelBuildsCalendarRequestFromCustomDateAndTimeFields() {
        let resolver = CardResultCustomFieldValueResolver()
        let calendar = Calendar.autoupdatingCurrent
        let scheduledDate = calendar.date(
            from: DateComponents(year: 2026, month: 5, day: 15, hour: 14, minute: 30)
        )!
        let cardID = UUID()
        let viewModel = CardResultViewModel(
            card: .note(
                NoteCard(
                    metadata: CardMetadata(
                        id: cardID,
                        confidence: .medium,
                        confidenceScore: 0.72
                    ),
                    title: "Budget review",
                    summary: ""
                )
            ),
            cardRepository: InMemoryCardRepository(),
            reminderCreator: MockReminderCreator(),
            calendarCreator: MockCalendarCreator()
        )

        viewModel.addCustomField(type: .date, value: resolver.dateString(from: scheduledDate))
        viewModel.addCustomField(type: .time, value: resolver.timeString(from: scheduledDate))
        viewModel.addCustomField(type: .location, value: "  Conference Room A  ")
        viewModel.addCustomField(type: .note, value: "Bring invoices")

        let request = viewModel.calendarActionState.request
        let requestComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: request!.startDate)

        #expect(request?.sourceCardID == cardID)
        #expect(request?.title == "Budget review")
        #expect(request?.location == "Conference Room A")
        #expect(request?.notes == "Bring invoices")
        #expect(requestComponents.year == 2026)
        #expect(requestComponents.month == 5)
        #expect(requestComponents.day == 15)
        #expect(requestComponents.hour == 14)
        #expect(requestComponents.minute == 30)
        #expect(abs(request!.endDate.timeIntervalSince(request!.startDate) - 3_600) < 0.001)
    }

    @Test func calendarActionResolverBuildsRequestFromCustomFields() {
        let resolver = CardResultCustomFieldValueResolver()
        let calendar = Calendar.autoupdatingCurrent
        let scheduledDate = calendar.date(
            from: DateComponents(year: 2026, month: 5, day: 15, hour: 14, minute: 30)
        )!
        let cardID = UUID()
        let actionCard = ActionCard.note(
            NoteCard(
                metadata: CardMetadata(
                    id: cardID,
                    confidence: .medium,
                    confidenceScore: 0.72
                ),
                title: "Budget review",
                summary: ""
            )
        )
        let customFields = [
            CardResultCustomField(type: .date, value: resolver.dateString(from: scheduledDate)),
            CardResultCustomField(type: .time, value: resolver.timeString(from: scheduledDate)),
            CardResultCustomField(type: .location, value: "  Conference Room A  "),
            CardResultCustomField(type: .note, value: "Bring invoices")
        ]

        let request = CardResultCalendarActionResolver()
            .actionState(for: actionCard, customFields: customFields)
            .request
        let requestComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: request!.startDate)

        #expect(request?.sourceCardID == cardID)
        #expect(request?.title == "Budget review")
        #expect(request?.location == "Conference Room A")
        #expect(request?.notes == "Bring invoices")
        #expect(requestComponents.year == 2026)
        #expect(requestComponents.month == 5)
        #expect(requestComponents.day == 15)
        #expect(requestComponents.hour == 14)
        #expect(requestComponents.minute == 30)
        #expect(abs(request!.endDate.timeIntervalSince(request!.startDate) - 3_600) < 0.001)
    }

    @Test func savedInsightCardCopiesCreatedReminderStateFromActionCard() {
        let reminderID = "reminder-123"
        let card = ReminderCard(
            metadata: CardMetadata(
                confidence: .high,
                confidenceScore: 0.93
            ),
            title: "Follow up",
            reminderExternalID: reminderID
        )
        let insight = GeneratedInsightCard(
            title: "Follow up",
            usefulness: .useful,
            confidence: 0.93,
            summary: nil,
            sections: []
        )

        let savedCard = SavedInsightCard(
            insight: insight,
            actionCard: .reminder(card)
        )

        #expect(savedCard.reminderExternalID == reminderID)
        #expect(savedCard.effectiveReminderExternalID == reminderID)
        #expect(savedCard.reminderRequest == nil)
        #expect(savedCard.supportsReminderAction)
    }

    @Test func savedInsightCardReadsLegacyActionCardReminderState() {
        let reminderID = "legacy-reminder-123"
        let card = ShoppingCard(
            metadata: CardMetadata(
                confidence: .medium,
                confidenceScore: 0.72
            ),
            productName: "Keyboard",
            reminderExternalID: reminderID
        )
        let insight = GeneratedInsightCard(
            title: "Keyboard deal",
            usefulness: .useful,
            confidence: 0.72,
            summary: nil,
            sections: []
        )

        let savedCard = SavedInsightCard(
            metadata: CardMetadata(
                confidence: .medium,
                confidenceScore: 0.72
            ),
            insight: insight,
            actionCard: .shopping(card)
        )

        #expect(savedCard.reminderExternalID == nil)
        #expect(savedCard.effectiveReminderExternalID == reminderID)
        #expect(savedCard.reminderRequest == nil)
        #expect(savedCard.supportsReminderAction)
    }

    @Test func mockHomeSeedCardsProvideTenUniqueCards() {
        let cards = MockHomeSeedCards.cards()

        #expect(cards.count == 10)
        #expect(Set(cards.map(\.id)).count == 10)
        #expect(cards.contains { $0.effectiveReminderExternalID != nil })
        #expect(cards.contains { $0.effectiveCalendarExternalID != nil })
    }

    @Test @MainActor func detailViewModelCreatesReminderForNoteCard() async {
        let savedCard = noteSavedInsightCard()
        let repository = InMemoryCardRepository(seedCards: [savedCard])
        let viewModel = CardDetailViewModel(
            cardID: savedCard.id,
            cardRepository: repository,
            reminderCreator: MockReminderCreator(),
            calendarCreator: MockCalendarCreator()
        )

        await viewModel.load()
        viewModel.addCustomField(type: .note, value: "  Bring launch checklist  ")

        #expect(viewModel.showsReminderAction)
        #expect(viewModel.canCreateReminder)
        #expect(!viewModel.didCreateReminder)

        let updatedCard = await viewModel.createReminder()

        #expect(updatedCard?.effectiveReminderExternalID != nil)
        #expect(viewModel.didCreateReminder)
        #expect(!viewModel.canCreateReminder)
    }

    @Test @MainActor func detailViewModelShowsCreatedReminderState() async {
        let savedCard = noteSavedInsightCard(reminderExternalID: "mock-created-reminder")
        let repository = InMemoryCardRepository(seedCards: [savedCard])
        let viewModel = CardDetailViewModel(
            cardID: savedCard.id,
            cardRepository: repository,
            reminderCreator: MockReminderCreator(),
            calendarCreator: MockCalendarCreator()
        )

        await viewModel.load()

        #expect(viewModel.showsReminderAction)
        #expect(viewModel.didCreateReminder)
        #expect(!viewModel.canCreateReminder)
    }

    @Test @MainActor func cardResultViewModelPersistsCustomFieldsWhenSaving() async {
        let repository = InMemoryCardRepository()
        let cardID = UUID()
        let metadata = CardMetadata(
            id: cardID,
            confidence: .medium,
            confidenceScore: 0.74
        )
        let viewModel = CardResultViewModel(
            card: .note(
                NoteCard(
                    metadata: metadata,
                    title: "Design meetup",
                    summary: "Meetup details."
                )
            ),
            cardRepository: repository,
            reminderCreator: MockReminderCreator(),
            calendarCreator: MockCalendarCreator()
        )
        let insight = GeneratedInsightCard(
            id: cardID,
            title: "Design meetup",
            usefulness: .useful,
            confidence: 0.74,
            summary: "Meetup details.",
            sections: []
        )

        viewModel.completeGeneration(card: viewModel.card, content: insight)
        viewModel.addCustomField(type: .location, value: "Taipei")
        viewModel.addCustomField(type: .note, value: "Bring portfolio")

        let savedCard = await viewModel.save()
        let fetchedCard = try? await repository.fetchCard(id: cardID)

        #expect(savedCard?.customFields.map(\.value) == ["Taipei", "Bring portfolio"])
        #expect(fetchedCard?.customFields.map(\.value) == ["Taipei", "Bring portfolio"])
    }

    @Test @MainActor func cardResultViewModelIgnoresRepeatedReminderCreation() async {
        let reminderCreator = CountingReminderCreator()
        let metadata = CardMetadata(
            confidence: .medium,
            confidenceScore: 0.74
        )
        let viewModel = CardResultViewModel(
            card: .reminder(
                ReminderCard(
                    metadata: metadata,
                    title: "Follow up",
                    notes: "Send launch checklist"
                )
            ),
            cardRepository: InMemoryCardRepository(),
            reminderCreator: reminderCreator,
            calendarCreator: MockCalendarCreator()
        )

        await viewModel.createReminder()
        await viewModel.createReminder()

        #expect(await reminderCreator.createCount == 1)
        #expect(viewModel.didCreateReminder)
        #expect(!viewModel.canCreateReminder)
    }

    @Test @MainActor func cardResultViewModelIgnoresRepeatedCalendarCreation() async {
        let calendarCreator = CountingCalendarCreator()
        let metadata = CardMetadata(
            confidence: .medium,
            confidenceScore: 0.74
        )
        let startDate = Date()
        let viewModel = CardResultViewModel(
            card: .calendar(
                CalendarCard(
                    metadata: metadata,
                    title: "Launch review",
                    startDate: startDate,
                    endDate: startDate.addingTimeInterval(3_600),
                    notes: "Review checklist"
                )
            ),
            cardRepository: InMemoryCardRepository(),
            reminderCreator: MockReminderCreator(),
            calendarCreator: calendarCreator
        )

        await viewModel.createCalendarEvent()
        await viewModel.createCalendarEvent()

        #expect(await calendarCreator.createCount == 1)
        #expect(viewModel.didCreateCalendar)
        #expect(!viewModel.canCreateCalendar)
    }

    @Test @MainActor func inboxSearchImmediatelySearchesAcrossFilters() async throws {
        let activeCard = savedInsightCard(title: "Active launch plan", status: .saved)
        let archivedCard = savedInsightCard(title: "Vendor renewal contract", status: .archived)
        let repository = InMemoryCardRepository(seedCards: [activeCard, archivedCard])
        let viewModel = InboxViewModel(cardRepository: repository)

        await viewModel.loadIfNeeded()
        viewModel.selectedFilter = .category(.other)
        #expect(viewModel.filteredCards.map(\.id) == [activeCard.id])

        viewModel.searchText = "vendor"
        #expect(viewModel.filteredCards.map(\.id) == [archivedCard.id])

        viewModel.searchText = "jh"
        #expect(viewModel.filteredCards.isEmpty)
        #expect(viewModel.emptyStateTitle == "No matching insights")

        viewModel.searchText = ""
        #expect(viewModel.filteredCards.map(\.id) == [activeCard.id])
    }

    @Test @MainActor func swiftDataCardRepositoryPersistsSavedCards() async throws {
        let repository = try swiftDataRepository()
        let customFields = [
            CardResultCustomField(type: .location, value: "Taipei"),
            CardResultCustomField(type: .note, value: "Bring portfolio")
        ]
        let card = noteSavedInsightCard(customFields: customFields)

        let savedCard = try await repository.save(card)
        let fetchedCard = try await repository.fetchCard(id: card.id)
        let recentCards = try await repository.fetchRecentCards(limit: 1, includeArchived: false)

        #expect(savedCard.status == .saved)
        #expect(fetchedCard == savedCard)
        #expect(recentCards == [savedCard])
        #expect(fetchedCard?.customFields == customFields)
    }

    @Test func swiftDataCardRepositoryUpdatesArchivesAndDeletesCards() async throws {
        let repository = try swiftDataRepository()
        let card = noteSavedInsightCard()
        _ = try await repository.save(card)

        let completedCard = card.applyingReminderResult(
            ExternalActionResult(
                kind: .reminder,
                externalID: "created-reminder-id",
                displayName: "Created reminder"
            )
        )
        let updatedCard = try await repository.update(completedCard)
        let archivedCard = try await repository.archiveCard(id: card.id)
        let visibleCards = try await repository.fetchCards(includeArchived: false)
        let allCards = try await repository.fetchCards(includeArchived: true)

        #expect(updatedCard.effectiveReminderExternalID == "created-reminder-id")
        #expect(archivedCard.status == .archived)
        #expect(visibleCards.isEmpty)
        #expect(allCards.map(\.id) == [card.id])

        try await repository.deleteCard(id: card.id)
        #expect(try await repository.fetchCard(id: card.id) == nil)
    }

    @Test func sourceImageFileStoreResolvesRelativePath() throws {
        let baseDirectory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: baseDirectory) }

        let store = try SourceImageFileStore(baseDirectory: baseDirectory)
        let imageDirectory = baseDirectory.appendingPathComponent("SourceImages", isDirectory: true)
        try FileManager.default.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
        try Data("image-data".utf8).write(to: imageDirectory.appendingPathComponent("source.jpg"))

        let storedPath = "SourceImages/source.jpg"
        let resolvedPath = store.resolvedPath(for: storedPath)

        #expect(resolvedPath != nil)
        #expect(FileManager.default.fileExists(atPath: resolvedPath ?? ""))
    }

    @Test func sourceImageFileStoreResolvesLegacyAbsolutePathByFilename() throws {
        let baseDirectory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: baseDirectory) }

        let store = try SourceImageFileStore(baseDirectory: baseDirectory)
        let imageDirectory = baseDirectory.appendingPathComponent("SourceImages", isDirectory: true)
        try FileManager.default.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
        let migratedURL = imageDirectory.appendingPathComponent("legacy-source.jpg")
        try Data("image-data".utf8).write(to: migratedURL)

        let legacyPath = "/private/var/mobile/Containers/Data/Application/OLD/Library/Application Support/CaptureFlow/SourceImages/legacy-source.jpg"

        #expect(store.resolvedPath(for: legacyPath) == migratedURL.path)
    }

    @Test @MainActor func swiftDataCardRepositoryPreservesPhotoLibraryAssetIdentifier() async throws {
        let repository = try swiftDataRepository()
        let sourceImage = CardSourceImage(
            source: .photoLibrary,
            localPath: "SourceImages/source.jpg",
            assetLocalIdentifier: "photos-asset-id"
        )
        let card = noteSavedInsightCard(sourceImage: sourceImage)

        _ = try await repository.save(card)
        let fetchedCard = try await repository.fetchCard(id: card.id)

        #expect(fetchedCard?.sourceImage?.assetLocalIdentifier == "photos-asset-id")
        #expect(fetchedCard?.sourceImage?.localPath == "SourceImages/source.jpg")
    }

    private func swiftDataRepository() throws -> SwiftDataCardRepository {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let modelContainer = try ModelContainer(
            for: SwiftDataSavedInsightCard.self,
            configurations: configuration
        )

        return SwiftDataCardRepository(modelContainer: modelContainer)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("CaptureFlowTests-\(UUID().uuidString)", isDirectory: true)
    }

    private func noteSavedInsightCard(
        reminderExternalID: String? = nil,
        sourceImage: CardSourceImage? = nil,
        customFields: [CardResultCustomField] = []
    ) -> SavedInsightCard {
        let metadata = CardMetadata(
            sourceImage: sourceImage,
            confidence: .medium,
            confidenceScore: 0.78,
            status: reminderExternalID == nil ? .saved : .completed
        )
        let insight = GeneratedInsightCard(
            id: metadata.id,
            title: "Launch notes",
            usefulness: .useful,
            confidence: 0.78,
            summary: "Captured release checklist and launch owner details.",
            sections: []
        )

        return SavedInsightCard(
            metadata: metadata,
            insight: insight,
            actionCard: .note(
                NoteCard(
                    metadata: metadata,
                    title: "Launch notes",
                    summary: "Captured release checklist and launch owner details."
                )
            ),
            customFields: customFields,
            reminderExternalID: reminderExternalID
        )
    }

    private func savedInsightCard(
        title: String,
        status: CardStatus,
        createdAt: Date = .now
    ) -> SavedInsightCard {
        let metadata = CardMetadata(
            createdAt: createdAt,
            updatedAt: createdAt,
            confidence: .medium,
            confidenceScore: 0.78,
            status: status
        )
        let insight = GeneratedInsightCard(
            id: metadata.id,
            title: title,
            usefulness: .useful,
            confidence: 0.78,
            summary: "Search fixture for \(title).",
            sections: []
        )

        return SavedInsightCard(
            metadata: metadata,
            insight: insight
        )
    }
}

private actor CountingReminderCreator: ReminderCreating {
    private(set) var createCount = 0

    func createReminder(_ request: ReminderCreationRequest) async throws -> ExternalActionResult {
        createCount += 1
        return ExternalActionResult(
            kind: .reminder,
            sourceCardID: request.sourceCardID,
            externalID: "counting-reminder-\(createCount)",
            displayName: request.title
        )
    }
}

private actor CountingCalendarCreator: CalendarCreating {
    private(set) var createCount = 0

    func createCalendarEvent(_ request: CalendarCreationRequest) async throws -> ExternalActionResult {
        createCount += 1
        return ExternalActionResult(
            kind: .calendar,
            sourceCardID: request.sourceCardID,
            externalID: "counting-calendar-\(createCount)",
            displayName: request.title
        )
    }
}
