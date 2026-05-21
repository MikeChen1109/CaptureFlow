import Foundation

enum ServiceError: Error, Equatable, Sendable {
    case noImageProvided
    case unsupportedCardType(CardType)
    case permissionDenied
    case invalidGeneratedCard
    case unavailable(String)
}
