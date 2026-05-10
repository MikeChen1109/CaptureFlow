import Foundation

struct CardSourceImage: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var source: CardSource
    var localPath: String?
    var originalFilename: String?
    var capturedAt: Date

    init(
        id: UUID = UUID(),
        source: CardSource,
        localPath: String? = nil,
        originalFilename: String? = nil,
        capturedAt: Date = .now
    ) {
        self.id = id
        self.source = source
        self.localPath = localPath
        self.originalFilename = originalFilename
        self.capturedAt = capturedAt
    }
}
