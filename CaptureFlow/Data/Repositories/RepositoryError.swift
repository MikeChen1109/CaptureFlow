import Foundation

enum RepositoryError: Error, Equatable, Sendable {
    case cardNotFound(UUID)
}
