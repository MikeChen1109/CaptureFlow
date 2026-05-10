import Foundation

enum CardSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case camera
    case photoLibrary
    case shareExtension
    case mock

    var id: String { rawValue }
}
