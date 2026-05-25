import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum FoundationModelAvailability {
    enum Status: Equatable, Sendable {
        case available
        case deviceNotEligible
        case appleIntelligenceNotEnabled
        case modelNotReady
        case unsupportedOS
        case unavailable

        nonisolated var isAvailable: Bool {
            if case .available = self {
                return true
            }

            return false
        }
    }

    nonisolated static var current: Status {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(.deviceNotEligible):
                return .deviceNotEligible
            case .unavailable(.appleIntelligenceNotEnabled):
                return .appleIntelligenceNotEnabled
            case .unavailable(.modelNotReady):
                return .modelNotReady
            @unknown default:
                return .unavailable
            }
        }
        #endif

        return .unsupportedOS
    }

    nonisolated static var isAvailable: Bool {
        current.isAvailable
    }
}
