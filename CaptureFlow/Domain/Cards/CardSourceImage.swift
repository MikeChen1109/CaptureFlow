import Foundation

struct CardSourceImage: nonisolated Codable, nonisolated Hashable, Identifiable, Sendable {
    var id: UUID
    var source: CardSource
    var localPath: String?
    var assetLocalIdentifier: String?
    var originalFilename: String?
    var capturedAt: Date

    init(
        id: UUID = UUID(),
        source: CardSource,
        localPath: String? = nil,
        assetLocalIdentifier: String? = nil,
        originalFilename: String? = nil,
        capturedAt: Date = .now
    ) {
        self.id = id
        self.source = source
        self.localPath = localPath
        self.assetLocalIdentifier = assetLocalIdentifier
        self.originalFilename = originalFilename
        self.capturedAt = capturedAt
    }
}
