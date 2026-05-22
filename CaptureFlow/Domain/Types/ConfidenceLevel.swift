import Foundation

enum ConfidenceLevel: String, nonisolated Codable, nonisolated Hashable, CaseIterable, Identifiable, Sendable {
    case low
    case medium
    case high

    var id: String { rawValue }

    static func from(score: Double) -> ConfidenceLevel {
        switch score {
        case ..<0.55:
            .low
        case ..<0.8:
            .medium
        default:
            .high
        }
    }
}
