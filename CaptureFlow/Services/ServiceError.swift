import Foundation

enum ServiceError: Error, Equatable, Sendable {
    case noImageProvided
    case unsupportedCardType(CardType)
    case insufficientCredits
    case permissionDenied
    case invalidGeneratedCard
    case unavailable(String)
}
