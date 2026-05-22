import Foundation

enum CardStatus: String, nonisolated Codable, nonisolated Hashable, CaseIterable, Identifiable, Sendable {
    case pending
    case saved
    case completed
    case archived

    var id: String { rawValue }
}
