import Foundation

enum GenerationModelSelection: String, CaseIterable, Identifiable, Sendable {
    case externalLLM
    case foundationModels

    var id: String { rawValue }

    init(storedRawValue: String?) {
        guard let storedRawValue else {
            self = .externalLLM
            return
        }

        if storedRawValue == "openAI" {
            self = .externalLLM
            return
        }

        self = GenerationModelSelection(rawValue: storedRawValue) ?? .externalLLM
    }

    var title: String {
        switch self {
        case .externalLLM:
            "External LLM"
        case .foundationModels:
            "Foundation Model"
        }
    }

    var detail: String {
        switch self {
        case .externalLLM:
            "Use the configured external LLM provider. The default provider is OpenAI."
        case .foundationModels:
            "Requires iOS 26 or later with Apple Intelligence enabled."
        }
    }
}

struct GenerationProviderConfiguration: Sendable {
    var modelSelection: GenerationModelSelection
}

final class GenerationProviderSettingsStore: @unchecked Sendable {
    static let shared = GenerationProviderSettingsStore()

    private let userDefaults: UserDefaults

    init(
        userDefaults: UserDefaults = .standard
    ) {
        self.userDefaults = userDefaults
    }

    func configuration() -> GenerationProviderConfiguration {
        GenerationProviderConfiguration(
            modelSelection: modelSelection
        )
    }

    var modelSelection: GenerationModelSelection {
        get {
            GenerationModelSelection(
                storedRawValue: userDefaults.string(forKey: GenerationPreferences.Keys.generationModelSelection)
            )
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: GenerationPreferences.Keys.generationModelSelection)
        }
    }
}

extension GenerationPreferences.Keys {
    static let generationModelSelection = "settings.generationModelSelection"
}
