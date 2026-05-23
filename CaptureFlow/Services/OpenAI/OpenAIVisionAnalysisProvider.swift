import Foundation

struct OpenAIVisionAnalysisProvider: VisionAnalysisProviding {
    let providerID = "openai"

    private let configuration: OpenAIConfiguration
    private let urlSession: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        configuration: OpenAIConfiguration,
        urlSession: URLSession = .shared
    ) {
        self.configuration = configuration
        self.urlSession = urlSession
        self.encoder = JSONEncoder()

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
        OpenAIResponsesRequestDTO(
            prompt: OpenAIResponsesRequestDTO.Prompt(
                id: configuration.promptID,
                version: configuration.promptVersion
            ),
            input: [
                OpenAIResponsesRequestDTO.InputMessage(
                    role: "user",
                    content: [
                        .inputText(Self.analysisInstructions(selectedCardType: request.selectedCardType)),
                        .inputImage(imageURL: dataURL(from: request.imageData))
                    ]
                )
            ]
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

    private static func analysisInstructions(selectedCardType: CardType) -> String {
        """
        Analyze this image for CaptureFlow.
        Selected card type: \(selectedCardType.rawValue).
        Return only a JSON object matching this shape:
        {
          "resolved_card_type": "unknown|shopping|event|note|job|travel|food|receipt|article|product|reminder|contact|promotion|document|appScreen|other",
          "scene_title": "short title",
          "scene_summary": "summary based only on visible evidence",
          "user_intent_guess": "likely intent, if any",
          "visible_text": ["text found in the image"],
          "visual_objects": ["objects visible in the image"],
          "layout_description": "brief layout",
          "entities": [{"type":"product|price|promotion|store|date|time|location|company|role|skill|url|contact|note|event|unknown","label":"Label","value":"Value","confidence":0.0}],
          "possible_actions": [{"title":"Action","description":"Why","action_type":"save|reminder|calendar|copy|share|compare|followUp|custom"}],
          "constraints": ["uncertainties"],
          "missing_info": ["important missing info"],
          "recommended_plan_title": "plan title",
          "confidence_score": 0.0,
          "evidence": ["specific visible evidence"]
        }
        Do not include source image paths, file names, device paths, or local asset identifiers.
        """
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
    var prompt: Prompt
    var input: [InputMessage]

    struct Prompt: Encodable {
        var id: String
        var version: String
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
}
