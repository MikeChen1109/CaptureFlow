import Foundation

struct LLMProviderID: RawRepresentable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    static let openAI = LLMProviderID(rawValue: "openAI")
}

protocol LLMProviderCredentialProviding: Sendable {
    func apiKey(for providerID: LLMProviderID) throws -> String?
}

struct StaticLLMProviderCredentialProvider: LLMProviderCredentialProviding {
    private let apiKeys: [LLMProviderID: String]

    init(apiKeys: [LLMProviderID: String] = [:]) {
        self.apiKeys = apiKeys
    }

    init(openAIAPIKey: String?) {
        if let openAIAPIKey {
            apiKeys = [.openAI: openAIAPIKey]
        } else {
            apiKeys = [:]
        }
    }

    func apiKey(for providerID: LLMProviderID) throws -> String? {
        apiKeys[providerID]?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
