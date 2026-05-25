import Foundation
import Testing
@testable import CaptureFlow

@MainActor
struct SettingsViewModelTests {
    @Test func unavailableFoundationSelectionFallsBackToExternalLLMOnInit() {
        let store = makeSettingsStore()
        store.modelSelection = .foundationModels

        let viewModel = SettingsViewModel(
            cardRepository: InMemoryCardRepository(),
            providerSettingsStore: store,
            foundationModelAvailabilityProvider: { .appleIntelligenceNotEnabled }
        )

        #expect(viewModel.generationModelSelection == .externalLLM)
        #expect(store.modelSelection == .externalLLM)
        #expect(viewModel.isFoundationModelOptionEnabled == false)
        #expect(viewModel.foundationModelStatusTitle == "Apple Intelligence is off")
    }

    @Test func refreshResetsFoundationSelectionWhenItBecomesUnavailable() {
        var availability = FoundationModelAvailability.Status.available
        let store = makeSettingsStore()
        store.modelSelection = .foundationModels

        let viewModel = SettingsViewModel(
            cardRepository: InMemoryCardRepository(),
            providerSettingsStore: store,
            foundationModelAvailabilityProvider: { availability }
        )
        #expect(viewModel.generationModelSelection == .foundationModels)

        availability = .modelNotReady
        viewModel.refreshGenerationAvailability()

        #expect(viewModel.generationModelSelection == .externalLLM)
        #expect(store.modelSelection == .externalLLM)
        #expect(viewModel.foundationModelStatusTitle == "Model not ready")
    }

    private func makeSettingsStore() -> GenerationProviderSettingsStore {
        let suiteName = "CaptureFlowTests.SettingsViewModel.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)

        return GenerationProviderSettingsStore(userDefaults: userDefaults)
    }
}
