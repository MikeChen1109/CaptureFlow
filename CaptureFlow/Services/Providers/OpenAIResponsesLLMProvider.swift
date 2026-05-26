import Foundation

struct OpenAIResponsesLLMProvider: LLMProviding {
    private let credentialProvider: any LLMProviderCredentialProviding
    private let endpoint: URL
    private let timeoutInterval: TimeInterval
    private let maxRetryCount: Int

    init(
        credentialProvider: any LLMProviderCredentialProviding,
        endpoint: URL = URL(string: "https://api.openai.com/v1/responses")!,
        timeoutInterval: TimeInterval = 45,
        maxRetryCount: Int = 2
    ) {
        self.credentialProvider = credentialProvider
        self.endpoint = endpoint
        self.timeoutInterval = timeoutInterval
        self.maxRetryCount = maxRetryCount
    }

    func responseText(for request: LLMRequest) async throws -> String {
        guard let apiKey = try credentialProvider.apiKey(for: .openAI), !apiKey.isEmpty else {
            throw ServiceError.unavailable("OpenAI API key is not configured in this build.")
        }

        let requestBody = try requestBody(for: request)
        let responseData = try await performRequest(requestBody: requestBody, apiKey: apiKey)
        let response = try JSONDecoder().decode(OpenAIResponsesAPIResponse.self, from: responseData)

        guard let outputText = response.outputText?.trimmingCharacters(in: .whitespacesAndNewlines),
              !outputText.isEmpty
        else {
            throw ServiceError.invalidGeneratedCard
        }

        return outputText
    }

    private func requestBody(for request: LLMRequest) throws -> Data {
        var body: [String: Any] = [
            "model": request.model,
            "instructions": request.instructions,
            "input": inputPayload(for: request.input)
        ]

        if let responseFormat = request.responseFormat {
            body["text"] = [
                "format": [
                    "type": "json_schema",
                    "name": responseFormat.name,
                    "strict": responseFormat.isStrict,
                    "schema": responseFormat.schema
                ]
            ]
        }

        return try JSONSerialization.data(withJSONObject: body)
    }

    private func inputPayload(for input: LLMRequest.Input) -> Any {
        switch input {
        case .text(let text):
            return text
        }
    }

    private func performRequest(requestBody: Data, apiKey: String) async throws -> Data {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeoutInterval
        configuration.timeoutIntervalForResource = timeoutInterval
        let session = URLSession(configuration: configuration)

        var lastError: Error?

        for attempt in 0...maxRetryCount {
            do {
                var request = URLRequest(url: endpoint)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                request.httpBody = requestBody

                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw ServiceError.unavailable("The provider returned an invalid response.")
                }

                guard (200..<300).contains(httpResponse.statusCode) else {
                    throw ProviderErrorMapper.error(statusCode: httpResponse.statusCode, data: data)
                }

                return data
            } catch {
                lastError = error

                guard attempt < maxRetryCount, isRetryable(error) else {
                    break
                }

                try await Task.sleep(for: .milliseconds(300 * (attempt + 1)))
            }
        }

        throw ProviderErrorMapper.normalizedError(lastError)
    }

    private func isRetryable(_ error: Error) -> Bool {
        if let serviceError = error as? ServiceError {
            return serviceError.userFacingMessage.localizedCaseInsensitiveContains("temporarily unavailable")
        }

        guard let urlError = error as? URLError else {
            return false
        }

        switch urlError.code {
        case .timedOut, .networkConnectionLost, .notConnectedToInternet, .cannotConnectToHost:
            return true
        default:
            return false
        }
    }
}

enum ProviderErrorMapper {
    static func error(statusCode: Int, data: Data) -> Error {
        let providerMessage = try? JSONDecoder()
            .decode(OpenAIErrorEnvelope.self, from: data)
            .error?
            .message

        switch statusCode {
        case 401, 403:
            return ServiceError.unavailable("The provider key was rejected. Check the saved API key.")
        case 408, 409, 429, 500...599:
            return ServiceError.unavailable("The provider is temporarily unavailable. Try again in a moment.")
        default:
            return ServiceError.unavailable(providerMessage ?? "The provider could not complete this request.")
        }
    }

    static func normalizedError(_ error: Error?) -> Error {
        if let serviceError = error as? ServiceError {
            return serviceError
        }

        if error is URLError {
            return ServiceError.unavailable("The provider request failed. Check your connection and try again.")
        }

        return error ?? ServiceError.unavailable("The provider request failed.")
    }
}

private struct OpenAIResponsesAPIResponse: Decodable {
    var outputText: String?
    var output: [OpenAIResponseOutputItem]?

    enum CodingKeys: String, CodingKey {
        case outputText = "output_text"
        case output
    }

    var resolvedOutputText: String? {
        outputText ?? output?
            .flatMap { $0.content ?? [] }
            .compactMap(\.text)
            .joined(separator: "\n")
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        outputText = try container.decodeIfPresent(String.self, forKey: .outputText)
        output = try container.decodeIfPresent([OpenAIResponseOutputItem].self, forKey: .output)
        outputText = resolvedOutputText
    }
}

private struct OpenAIResponseOutputItem: Decodable {
    var content: [OpenAIResponseContent]?
}

private struct OpenAIResponseContent: Decodable {
    var text: String?
}

private struct OpenAIErrorEnvelope: Decodable {
    var error: OpenAIAPIError?
}

private struct OpenAIAPIError: Decodable {
    var message: String
}
