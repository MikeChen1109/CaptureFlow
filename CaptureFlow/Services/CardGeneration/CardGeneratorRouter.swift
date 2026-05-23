import Foundation

struct CardGeneratorRouter: CardGenerating {
    private let settingsStore: GenerationProviderSettingsStore
    private let providerGenerator: any CardGenerating
    private let foundationGenerator: (any CardGenerating)?
    private let mockGenerator: any CardGenerating
    private let isFoundationModelsAvailable: @Sendable () -> Bool

    init(
        settingsStore: GenerationProviderSettingsStore,
        providerGenerator: any CardGenerating,
        foundationGenerator: (any CardGenerating)?,
        mockGenerator: any CardGenerating,
        isFoundationModelsAvailable: @escaping @Sendable () -> Bool = { FoundationModelAvailability.isAvailable }
    ) {
        self.settingsStore = settingsStore
        self.providerGenerator = providerGenerator
        self.foundationGenerator = foundationGenerator
        self.mockGenerator = mockGenerator
        self.isFoundationModelsAvailable = isFoundationModelsAvailable
    }

    func streamGeneratedContent(
        from context: VisionUnderstandingContext
    ) -> AsyncThrowingStream<CardGenerationEvent, Error> {
        switch resolvedRoute() {
        case .provider:
            logGenerationMode("Provider")
            return providerGenerator.streamGeneratedContent(from: context)
        case .foundationModels:
            logGenerationMode("FoundationModels")
            return foundationGenerator?.streamGeneratedContent(from: context)
                ?? mockGenerator.streamGeneratedContent(from: context)
        case .mock:
            logGenerationMode("Mock")
            return mockGenerator.streamGeneratedContent(from: context)
        }
    }

    private func resolvedRoute() -> CardGenerationRoute {
        let configuration = settingsStore.configuration()

        if configuration.modelSelection == .externalLLM {
            return .provider
        }

        if foundationGenerator != nil, isFoundationModelsAvailable() {
            return .foundationModels
        }

        return .provider
    }

    private func logGenerationMode(_ mode: String) {
        #if DEBUG
        print("[CaptureFlow][CardGenerator] Mode=\(mode)")
        #endif
    }
}

enum CardGenerationRoute: Sendable {
    case provider
    case foundationModels
    case mock
}

enum CardGenerationModeResolver {
    static func current(
        settingsStore: GenerationProviderSettingsStore,
        providerDisplayName: String,
        isFoundationModelsAvailable: Bool
    ) -> CardGenerationRuntimeMode {
        let configuration = settingsStore.configuration()

        if configuration.modelSelection == .externalLLM {
            return .provider(providerDisplayName)
        }

        if isFoundationModelsAvailable {
            return .foundationModels
        }

        return .provider(providerDisplayName)
    }
}

enum CardGenerationRuntimeMode: Equatable, Sendable {
    case provider(String)
    case foundationModels
    case mock

    var title: String {
        switch self {
        case .provider(let name):
            "Provider: \(name)"
        case .foundationModels:
            "Apple Foundation Models"
        case .mock:
            "Mock fallback"
        }
    }

    var detail: String {
        switch self {
        case .provider:
            "Using the configured external LLM provider for generation."
        case .foundationModels:
            "Using Apple on-device Foundation Models. Requires iOS 26 or later with Apple Intelligence enabled."
        case .mock:
            "Using deterministic local fallback content."
        }
    }
}
