import Foundation

enum AppRoute: Hashable, Sendable {
    case capturePreview
    case analysis
    case cardResult(UUID)
    case cardDetail(UUID)
    case settings
}
