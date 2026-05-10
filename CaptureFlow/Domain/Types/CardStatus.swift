import Foundation

enum CardStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case pending
    case saved
    case completed
    case archived

    var id: String { rawValue }
}
