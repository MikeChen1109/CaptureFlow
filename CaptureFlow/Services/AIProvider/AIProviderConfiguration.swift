import Foundation

struct AIProviderConfiguration: Sendable {
    enum Provider: String, Sendable {
        case mock
        case openAI = "openai"
    }

    var provider: Provider
    var openAI: OpenAIConfiguration

    static func current(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        bundle: Bundle = .main
    ) -> AIProviderConfiguration {
        let secrets = LocalSecrets(bundle: bundle)
        let provider = Provider(
            rawValue: environment["CAPTUREFLOW_AI_PROVIDER"]?.lowercased() ?? secrets.string(for: "CAPTUREFLOW_AI_PROVIDER")?.lowercased() ?? ""
        ) ?? .mock

        return AIProviderConfiguration(
            provider: provider,
            openAI: OpenAIConfiguration(
                apiKey: environment["CAPTUREFLOW_OPENAI_API_KEY"]
                    ?? environment["OPENAI_API_KEY"]
                    ?? secrets.string(for: "CAPTUREFLOW_OPENAI_API_KEY")
                    ?? secrets.string(for: "OPENAI_API_KEY"),
                promptID: environment["CAPTUREFLOW_OPENAI_PROMPT_ID"]
                    ?? secrets.string(for: "CAPTUREFLOW_OPENAI_PROMPT_ID")
                    ?? OpenAIConfiguration.defaultPromptID,
                promptVersion: environment["CAPTUREFLOW_OPENAI_PROMPT_VERSION"]
                    ?? secrets.string(for: "CAPTUREFLOW_OPENAI_PROMPT_VERSION")
                    ?? OpenAIConfiguration.defaultPromptVersion,
                responsesURL: URL(
                    string: environment["CAPTUREFLOW_OPENAI_RESPONSES_URL"]
                        ?? secrets.string(for: "CAPTUREFLOW_OPENAI_RESPONSES_URL")
                        ?? OpenAIConfiguration.defaultResponsesURL
                ) ?? URL(string: OpenAIConfiguration.defaultResponsesURL)!
            )
        )
    }
}

extension AIProviderConfiguration: LLMProviderCredentialProviding {
    func apiKey(for providerID: LLMProviderID) throws -> String? {
        switch providerID {
        case .openAI:
            openAI.apiKey?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        default:
            nil
        }
    }
}

struct OpenAIConfiguration: Sendable {
    static let defaultPromptID = "pmpt_6a100bf25620819692356a4e45c3a7ec0d46de4235da0642"
    static let defaultPromptVersion = "2"
    static let defaultResponsesURL = "https://api.openai.com/v1/responses"

    var apiKey: String?
    var promptID: String
    var promptVersion: String
    var responsesURL: URL
}

private struct LocalSecrets {
    private let values: [String: Any]

    init(bundle: Bundle) {
        guard let url = bundle.url(forResource: "LocalSecrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            values = [:]
            return
        }

        values = plist
    }

    func string(for key: String) -> String? {
        (values[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
