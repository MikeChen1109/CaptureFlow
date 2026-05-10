import Foundation

struct CreditBalance: Codable, Hashable, Sendable {
    var remaining: Int
    var limit: Int
    var refreshedAt: Date

    nonisolated init(
        remaining: Int,
        limit: Int,
        refreshedAt: Date = .now
    ) {
        self.remaining = remaining
        self.limit = limit
        self.refreshedAt = refreshedAt
    }
}

enum CreditOperation: String, Codable, CaseIterable, Identifiable, Sendable {
    case analyzeImage

    var id: String { rawValue }
}
