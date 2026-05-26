import Foundation

protocol LLMProviding: Sendable {
    func responseText(for request: LLMRequest) async throws -> String
}

struct LLMRequest: Sendable {
    enum Input: Sendable {
        case text(String)
    }

    var model: String
    var instructions: String
    var input: Input
    var responseFormat: LLMResponseFormat?
}

struct LLMResponseFormat: Sendable {
    var name: String
    var schema: [String: Sendable]
    var isStrict: Bool

    init(name: String, schema: [String: Sendable], isStrict: Bool = true) {
        self.name = name
        self.schema = schema
        self.isStrict = isStrict
    }
}
