import Foundation

enum ServiceError: Error, Equatable, Sendable {
    case noImageProvided
    case unsupportedCardType(CardType)
    case permissionDenied
    case invalidGeneratedCard
    case unavailable(String)
}

extension ServiceError {
    var userFacingMessage: String {
        switch self {
        case .noImageProvided:
            "No image data was provided."
        case .unsupportedCardType(let cardType):
            "Unsupported card type: \(cardType.rawValue)."
        case .permissionDenied:
            "Permission denied."
        case .invalidGeneratedCard:
            "The generated card was missing required fields."
        case .unavailable(let message):
            message
        }
    }
}
