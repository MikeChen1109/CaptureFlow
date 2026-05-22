import Foundation
import SwiftData

@Model
final class SwiftDataSavedInsightCard {
    @Attribute(.unique) var id: UUID
    var title: String
    var cardTypeRawValue: String?
    var statusRawValue: String
    var createdAt: Date
    var updatedAt: Date
    var confidenceRawValue: String
    var confidenceScore: Double
    var insightUsefulnessRawValue: String
    var summary: String?
    var sourceRawValue: String?
    var sourceImageLocalPath: String?
    var sourceImageAssetLocalIdentifier: String?
    var sourceImageOriginalFilename: String?
    var sourceImageCapturedAt: Date?
    var reminderExternalID: String?
    var calendarExternalID: String?
    var schemaVersion: Int
    @Attribute(.externalStorage) var encodedCard: Data

    init(card: SavedInsightCard) throws {
        self.id = card.id
        self.title = card.title
        self.cardTypeRawValue = card.actionCard?.type.rawValue
        self.statusRawValue = card.status.rawValue
        self.createdAt = card.createdAt
        self.updatedAt = card.updatedAt
        self.confidenceRawValue = card.metadata.confidence.rawValue
        self.confidenceScore = card.metadata.confidenceScore
        self.insightUsefulnessRawValue = card.insight.usefulness.rawValue
        self.summary = card.insight.summary
        self.sourceRawValue = card.sourceImage?.source.rawValue
        self.sourceImageLocalPath = card.sourceImage?.localPath
        self.sourceImageAssetLocalIdentifier = card.sourceImage?.assetLocalIdentifier
        self.sourceImageOriginalFilename = card.sourceImage?.originalFilename
        self.sourceImageCapturedAt = card.sourceImage?.capturedAt
        self.reminderExternalID = card.effectiveReminderExternalID
        self.calendarExternalID = card.effectiveCalendarExternalID
        self.schemaVersion = 1
        self.encodedCard = try Self.encoder.encode(card)
    }

    func apply(_ card: SavedInsightCard) throws {
        id = card.id
        title = card.title
        cardTypeRawValue = card.actionCard?.type.rawValue
        statusRawValue = card.status.rawValue
        createdAt = card.createdAt
        updatedAt = card.updatedAt
        confidenceRawValue = card.metadata.confidence.rawValue
        confidenceScore = card.metadata.confidenceScore
        insightUsefulnessRawValue = card.insight.usefulness.rawValue
        summary = card.insight.summary
        sourceRawValue = card.sourceImage?.source.rawValue
        sourceImageLocalPath = card.sourceImage?.localPath
        sourceImageAssetLocalIdentifier = card.sourceImage?.assetLocalIdentifier
        sourceImageOriginalFilename = card.sourceImage?.originalFilename
        sourceImageCapturedAt = card.sourceImage?.capturedAt
        reminderExternalID = card.effectiveReminderExternalID
        calendarExternalID = card.effectiveCalendarExternalID
        schemaVersion = 1
        encodedCard = try Self.encoder.encode(card)
    }

    func decodedCard() throws -> SavedInsightCard {
        try Self.decoder.decode(SavedInsightCard.self, from: encodedCard)
    }

    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()
}
