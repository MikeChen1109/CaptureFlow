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
    @Published private(set) var isResetting = false
    @Published var errorMessage: String?
    @Published private(set) var actionMessage: String?

    private let cardRepository: any CardRepository
    private let externalLLMDisplayName: String
    let providerSettingsStore: GenerationProviderSettingsStore

    init(
        cardRepository: any CardRepository,
        providerSettingsStore: GenerationProviderSettingsStore,
        externalLLMDisplayName: String = LLMProviderConfiguration.openAIDefault.displayName
    ) {
        self.cardRepository = cardRepository
        self.providerSettingsStore = providerSettingsStore
        self.externalLLMDisplayName = externalLLMDisplayName

        let storedSelection = providerSettingsStore.modelSelection
        if storedSelection == .foundationModels, !Self.isFoundationModelsAvailable {
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

    func refreshProviderStatus() {
        let mode = CardGenerationModeResolver.current(
            settingsStore: providerSettingsStore,
            providerDisplayName: externalLLMDisplayName,
            isFoundationModelsAvailable: Self.isFoundationModelsAvailable
        )
        activeGenerationModeTitle = mode.title
        activeGenerationModeDetail = mode.detail
    }

    var isFoundationModelOptionEnabled: Bool {
        Self.isFoundationModelsAvailable
    }

    var foundationModelRequirementText: String {
        if isFoundationModelOptionEnabled {
            return "Available on this device. Requires iOS 26 or later with Apple Intelligence enabled."
        }

        return "Only available on iOS 26 or later when Apple Intelligence is enabled."
    }

    private static var isFoundationModelsAvailable: Bool {
        FoundationModelAvailability.isAvailable
    }
}
