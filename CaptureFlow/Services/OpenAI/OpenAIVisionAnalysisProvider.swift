import Foundation

struct OpenAIVisionAnalysisProvider: VisionAnalysisProviding {
    let providerID = "openai"

    private let configuration: OpenAIConfiguration
    private let urlSession: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let promptProvider: any VisionAnalysisPromptProviding

    init(
        configuration: OpenAIConfiguration,
        urlSession: URLSession = .shared,
        promptProvider: any VisionAnalysisPromptProviding = DefaultVisionAnalysisPromptProvider()
    ) {
        self.configuration = configuration
        self.urlSession = urlSession
        self.encoder = JSONEncoder()
        self.promptProvider = promptProvider

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder
    }

    func analyzeImage(_ request: VisionProviderAnalysisRequest) async throws -> VisionAnalysisDTO {
        guard let apiKey = configuration.apiKey?.trimmingCharacters(in: .whitespacesAndNewlines),
              !apiKey.isEmpty
        else {
            throw ServiceError.unavailable("OpenAI API key is not configured.")
        }

        var urlRequest = URLRequest(url: configuration.responsesURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try encoder.encode(openAIRequest(from: request))

        let (data, response) = try await urlSession.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.unavailable("OpenAI returned an invalid response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ServiceError.unavailable(openAIErrorMessage(from: data, statusCode: httpResponse.statusCode))
        }

        let responseDTO = try decoder.decode(OpenAIResponsesResponseDTO.self, from: data)
        guard let outputText = responseDTO.extractedOutputText else {
            throw ServiceError.unavailable("OpenAI response did not include analysis text.")
        }

        return try decodeAnalysisDTO(from: outputText)
    }

    private func openAIRequest(from request: VisionProviderAnalysisRequest) -> OpenAIResponsesRequestDTO {
        let prompt = promptProvider.prompt(
            for: VisionAnalysisPromptRequest(requestedCardType: request.selectedCardType)
        )
        let promptConfiguration = openAIPromptConfiguration

        return OpenAIResponsesRequestDTO(
            model: promptConfiguration == nil ? configuration.visionModel : nil,
            instructions: promptConfiguration == nil ? prompt.developerMessage : nil,
            prompt: promptConfiguration,
            text: OpenAIResponsesRequestDTO.Text(
                format: OpenAIResponsesRequestDTO.Text.Format(
                    name: VisionAnalysisResponseSchema.name,
                    schema: VisionAnalysisResponseSchema.schema
                )
            ),
            input: [
                OpenAIResponsesRequestDTO.InputMessage(
                    role: "user",
                    content: [
                        .inputText(prompt.userMessage),
                        .inputImage(imageURL: dataURL(from: request.imageData))
                    ]
                )
            ]
        )
    }

    private var openAIPromptConfiguration: OpenAIResponsesRequestDTO.Prompt? {
        guard let promptID = configuration.promptID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !promptID.isEmpty
        else {
            return nil
        }

        return OpenAIResponsesRequestDTO.Prompt(
            id: promptID,
            version: configuration.promptVersion?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
    }

    private func dataURL(from imageData: Data) -> String {
        "data:\(Self.mimeType(for: imageData));base64,\(imageData.base64EncodedString())"
    }

    private func decodeAnalysisDTO(from outputText: String) throws -> VisionAnalysisDTO {
        let jsonText = Self.extractedJSONObject(from: outputText)
        guard let data = jsonText.data(using: .utf8) else {
            throw ServiceError.unavailable("OpenAI response could not be converted to UTF-8.")
        }

        do {
            return try decoder.decode(VisionAnalysisDTO.self, from: data)
        } catch {
            throw ServiceError.unavailable("OpenAI response did not match the vision analysis DTO.")
        }
    }

    private func openAIErrorMessage(from data: Data, statusCode: Int) -> String {
        guard let error = try? decoder.decode(OpenAIErrorResponseDTO.self, from: data),
              let message = error.error.message.nonEmpty
        else {
            return "OpenAI request failed with status \(statusCode)."
        }

        return "OpenAI request failed with status \(statusCode): \(message)"
    }

    private static func mimeType(for data: Data) -> String {
        let bytes = [UInt8](data.prefix(12))

        if bytes.starts(with: [0xFF, 0xD8, 0xFF]) {
            return "image/jpeg"
        }

        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return "image/png"
        }

        if bytes.starts(with: [0x47, 0x49, 0x46]) {
            return "image/gif"
        }

        if bytes.count >= 12,
           bytes[0] == 0x52,
           bytes[1] == 0x49,
           bytes[2] == 0x46,
           bytes[3] == 0x46,
           bytes[8] == 0x57,
           bytes[9] == 0x45,
           bytes[10] == 0x42,
           bytes[11] == 0x50 {
            return "image/webp"
        }

        return "image/jpeg"
    }

    private static func extractedJSONObject(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("```") {
            let withoutOpeningFence = trimmed
                .replacingOccurrences(of: #"^```(?:json)?\s*"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"\s*```$"#, with: "", options: .regularExpression)
            return withoutOpeningFence.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let start = trimmed.firstIndex(of: "{"),
              let end = trimmed.lastIndex(of: "}"),
              start <= end
        else {
            return trimmed
        }

        return String(trimmed[start...end])
    }
}

private struct OpenAIResponsesRequestDTO: Encodable {
    var model: String?
    var instructions: String?
    var prompt: Prompt?
    var text: Text?
    var input: [InputMessage]

    struct Prompt: Encodable {
        var id: String
        var version: String?
    }

    struct Text: Encodable {
        var format: Format

        struct Format: Encodable {
            var type = "json_schema"
            var name: String
            var strict = true
            var schema: [String: Sendable]

            enum CodingKeys: String, CodingKey {
                case type
                case name
                case strict
                case schema
            }

            func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(type, forKey: .type)
                try container.encode(name, forKey: .name)
                try container.encode(strict, forKey: .strict)
                try container.encode(JSONObject(schema), forKey: .schema)
            }
        }
    }

    struct InputMessage: Encodable {
        var role: String
        var content: [InputContent]
    }

    enum InputContent: Encodable {
        case inputText(String)
        case inputImage(imageURL: String)

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case .inputText(let text):
                try container.encode("input_text", forKey: .type)
                try container.encode(text, forKey: .text)
            case .inputImage(let imageURL):
                try container.encode("input_image", forKey: .type)
                try container.encode(imageURL, forKey: .imageURL)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type
            case text
            case imageURL = "image_url"
        }
    }
}

private struct JSONObject: Encodable {
    var value: Any

    init(_ value: Any) {
        self.value = value
    }

    func encode(to encoder: any Encoder) throws {
        switch value {
        case let dictionary as [String: Any]:
            var container = encoder.container(keyedBy: DynamicCodingKey.self)
            for (key, value) in dictionary {
                try container.encode(JSONObject(value), forKey: DynamicCodingKey(stringValue: key))
            }
        case let array as [Any]:
            var container = encoder.unkeyedContainer()
            for value in array {
                try container.encode(JSONObject(value))
            }
        case let string as String:
            var container = encoder.singleValueContainer()
            try container.encode(string)
        case let int as Int:
            var container = encoder.singleValueContainer()
            try container.encode(int)
        case let double as Double:
            var container = encoder.singleValueContainer()
            try container.encode(double)
        case let bool as Bool:
            var container = encoder.singleValueContainer()
            try container.encode(bool)
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Unsupported JSON schema value."
                )
            )
        }
    }
}

private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(stringValue: String) {
        self.stringValue = stringValue
    }

    init(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

private struct OpenAIResponsesResponseDTO: Decodable {
    var outputText: String?
    var output: [OutputItem]?

    var extractedOutputText: String? {
        if let outputText = outputText?.nonEmpty {
            return outputText
        }

        return output?
            .flatMap(\.content)
            .compactMap(\.text)
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    struct OutputItem: Decodable {
        var content: [OutputContent]

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            content = try container.decodeIfPresent([OutputContent].self, forKey: .content) ?? []
        }

        private enum CodingKeys: String, CodingKey {
            case content
        }
    }

    struct OutputContent: Decodable {
        var text: String?
    }
}

private struct OpenAIErrorResponseDTO: Decodable {
    var error: OpenAIError

    struct OpenAIError: Decodable {
        var message: String
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var nilIfEmpty: String? {
        nonEmpty
    }
}
