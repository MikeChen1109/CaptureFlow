import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum FoundationModelAvailability {
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        }
        #endif

        return false
    }
}
