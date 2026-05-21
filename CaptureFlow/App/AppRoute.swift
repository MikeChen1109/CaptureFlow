import Foundation

enum AppRoute: Hashable, Sendable {
    case cardDetail(UUID)
    case inbox
    case settings
}
