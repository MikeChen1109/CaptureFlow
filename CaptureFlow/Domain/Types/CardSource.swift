import Foundation

enum CardSource: String, nonisolated Codable, nonisolated Hashable, CaseIterable, Identifiable, Sendable {
    case camera
    case photoLibrary
    case shareExtension
    case mock

    var id: String { rawValue }
}
