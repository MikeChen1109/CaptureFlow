import Combine
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var generationModelSelection: GenerationModelSelection {
        didSet {
            if generationModelSelection == .foundationModels, !isFoundationModelOptionEnabled {
                generationModelSelection = .externalLLM
                return
            }

            providerSettingsStore.modelSelection = generationModelSelection
            refreshProviderStatus()
        }
    }

    @Published private(set) var activeGenerationModeTitle = ""
    @Published private(set) var activeGenerationModeDetail = ""
    @Published private(set) var foundationModelAvailability: FoundationModelAvailability.Status = .unsupportedOS
    @Published private(set) var isResetting = false
    @Published var errorMessage: String?
    @Published private(set) var actionMessage: String?

    private let cardRepository: any CardRepository
    private let externalLLMDisplayName: String
    private let foundationModelAvailabilityProvider: () -> FoundationModelAvailability.Status
    let providerSettingsStore: GenerationProviderSettingsStore

    init(
        cardRepository: any CardRepository,
        providerSettingsStore: GenerationProviderSettingsStore,
        externalLLMDisplayName: String = LLMProviderConfiguration.openAIDefault.displayName,
        foundationModelAvailabilityProvider: @escaping () -> FoundationModelAvailability.Status = {
            FoundationModelAvailability.current
        }
    ) {
        self.cardRepository = cardRepository
        self.providerSettingsStore = providerSettingsStore
        self.externalLLMDisplayName = externalLLMDisplayName
        self.foundationModelAvailabilityProvider = foundationModelAvailabilityProvider
        let initialFoundationModelAvailability = foundationModelAvailabilityProvider()
        self.foundationModelAvailability = initialFoundationModelAvailability

        let storedSelection = providerSettingsStore.modelSelection
        if storedSelection == .foundationModels, !initialFoundationModelAvailability.isAvailable {
            generationModelSelection = .externalLLM
        } else {
            generationModelSelection = storedSelection
        }
        providerSettingsStore.modelSelection = generationModelSelection

        refreshProviderStatus()
    }

    func resetSavedInsights() async {
        isResetting = true
        errorMessage = nil
        actionMessage = nil

        do {
            try await cardRepository.reset()
            actionMessage = "Saved insights reset."
        } catch {
            errorMessage = "Unable to reset saved insights."
        }

        isResetting = false
    }

    func clearActionMessage() {
        actionMessage = nil
    }

    func refreshGenerationAvailability() {
        foundationModelAvailability = foundationModelAvailabilityProvider()

        if generationModelSelection == .foundationModels, !foundationModelAvailability.isAvailable {
            generationModelSelection = .externalLLM
            return
        }

        refreshProviderStatus()
    }

    func refreshProviderStatus() {
        let mode = CardGenerationModeResolver.current(
            settingsStore: providerSettingsStore,
            providerDisplayName: externalLLMDisplayName,
            isFoundationModelsAvailable: foundationModelAvailability.isAvailable
        )
        activeGenerationModeTitle = mode.title
        activeGenerationModeDetail = mode.detail
    }

    var isFoundationModelOptionEnabled: Bool {
        foundationModelAvailability.isAvailable
    }

    var usesFoundationModels: Bool {
        generationModelSelection == .foundationModels
    }

    func setUsesFoundationModels(_ isEnabled: Bool) {
        if isEnabled {
            generationModelSelection = .foundationModels
        } else {
            generationModelSelection = .externalLLM
        }
    }

    var foundationModelRequirementText: String {
        foundationModelAvailability.detail
    }

    var foundationModelStatusTitle: String {
        foundationModelAvailability.title
    }

    var foundationModelStatusSystemImage: String {
        foundationModelAvailability.systemImage
    }
}

private extension FoundationModelAvailability.Status {
    var title: String {
        switch self {
        case .available:
            "Available"
        case .deviceNotEligible:
            "Device not eligible"
        case .appleIntelligenceNotEnabled:
            "Apple Intelligence is off"
        case .modelNotReady:
            "Model not ready"
        case .unsupportedOS:
            "Requires iOS 26"
        case .unavailable:
            "Unavailable"
        }
    }

    var detail: String {
        switch self {
        case .available:
            "Ready on this device."
        case .deviceNotEligible:
            "This device does not support Apple Intelligence."
        case .appleIntelligenceNotEnabled:
            "Turn on Apple Intelligence in Settings to enable this option."
        case .modelNotReady:
            "The on-device model is still downloading or preparing."
        case .unsupportedOS:
            "Foundation Models require iOS 26 or later."
        case .unavailable:
            "Foundation Models are not available right now."
        }
    }

    var systemImage: String {
        switch self {
        case .available:
            "checkmark.circle.fill"
        case .modelNotReady:
            "clock.fill"
        default:
            "lock.fill"
        }
    }
}
