import Foundation

struct VisionAnalysisPromptRequest: Equatable, Sendable {
    var requestedCardType: CardType
}

struct VisionAnalysisPrompt: Equatable, Sendable {
    var developerMessage: String
    var userMessage: String
}

protocol VisionAnalysisPromptProviding: Sendable {
    func prompt(for request: VisionAnalysisPromptRequest) -> VisionAnalysisPrompt
}

struct DefaultVisionAnalysisPromptProvider: VisionAnalysisPromptProviding {
    func prompt(for request: VisionAnalysisPromptRequest) -> VisionAnalysisPrompt {
        VisionAnalysisPrompt(
            developerMessage: Self.developerMessage,
            userMessage: Self.userMessage(for: request)
        )
    }

    private static let developerMessage = """
    You are a vision understanding engine for CaptureFlow, a mobile screenshot organization app.

    Analyze the user-provided image and return a single JSON object that matches the provided schema.

    Your task:
    - Understand the image content.
    - Extract visible text as much as possible.
    - Identify visual objects, layout, entities, possible user actions, constraints, missing information, evidence, and confidence.
    - Infer the most suitable card type from the image.
    - Do not invent facts that are not visible or reasonably inferable from the image.
    - If information is uncertain, put it into missing_info or lower the confidence_score.
    - id fields, when present, must be UUID strings.
    - confidence_score and entity confidence values must be between 0 and 1.
    - Use only the allowed enum values.
    - Do not include source image paths, file names, device paths, or local asset identifiers.
    - Output JSON only.
    
    Text reconstruction rules:
    - visible_text must contain cleaned, human-readable text, not raw OCR fragments.
    - Reconstruct split lines into complete sentences or coherent bullet points.
    - Merge nearby fragments that are clearly part of the same sentence.
    - Treat comma-separated or wrapped technology lists as one coherent phrase unless there is a strong semantic reason to split them.
    - Do not keep standalone fragments that start with connector words such as "and", "or", "plus", "along with", "covering", "rendering", unless they are truly standalone headings.
    - Do not keep standalone fragments that are only a noun phrase completing a previous list, such as "native Android" after "native iOS".
    - If a text fragment depends on the previous line to make sense, merge it with the previous line.
    - Every visible_text item must be understandable if displayed alone.
    - Preserve semantic meaning over original visual line breaks.
    - For job descriptions, requirements, resumes, emails, articles, and documents, group text into complete requirement bullets or paragraphs.
    - Use evidence for raw observations, but visible_text should be suitable for display to end users.
    
    Text block rules:
    - When the image contains grouped text sections, create text_blocks.
    - Each text_block should represent one visual or semantic section.
    - raw_fragments may contain the imperfect visible fragments.
    - reconstructed_text must be cleaned and suitable for display.
    - reconstructed_text must not contain orphan clauses, hanging connectors, or fragments that only make sense with neighboring text.
    - visible_text should contain cleaned text only. Do not duplicate every raw fragment there.
    - For text-heavy screenshots, prefer text_blocks for preserving section structure.
    """

    private static func userMessage(for request: VisionAnalysisPromptRequest) -> String {
        """
        Analyze this image and generate a VisionAnalysisDTO.

        requested_card_type: \(request.requestedCardType.rawValue)

        Allowed CardType values:
        \(CardType.allCases.promptList)

        Allowed entity type values:
        \(VisionEntityType.allCases.promptList)

        Allowed action type values:
        \(VisionActionType.allCases.promptList)

        Required JSON keys:
        "resolved_card_type, scene_title, scene_summary, user_intent_guess, visible_text, text_blocks, visual_objects, layout_description, entities, possible_actions, constraints, missing_info, recommended_plan_title, confidence_score, evidence.",

        Entity objects must use:
        type, label, value, confidence.

        Possible action objects must use:
        title, description, action_type.

        Return this JSON shape:
        {
          "resolved_card_type": "unknown",
          "scene_title": "short title",
          "scene_summary": "summary based only on visible evidence",
          "user_intent_guess": "likely intent, if any",
          "visible_text": ["cleaned display text found in the image"],
          "text_blocks": [
            {
              "title": "section title if visible, otherwise null",
              "raw_fragments": ["raw OCR-like fragments from the same visual block"],
              "reconstructed_text": "cleaned, human-readable text reconstructed from the fragments",
              "confidence": 0.0
            }
          ],
          "visual_objects": ["objects visible in the image"],
          "layout_description": "brief layout",
          "entities": [{"type": "unknown", "label": "Label", "value": "Value", "confidence": 0.0}],
          "possible_actions": [{"title": "Action", "description": "Why", "action_type": "save"}],
          "constraints": ["uncertainties"],
          "missing_info": ["important missing info"],
          "recommended_plan_title": "plan title",
          "confidence_score": 0.0,
          "evidence": ["specific visible evidence"]
        }
        """
    }
}

enum VisionAnalysisResponseSchema {
    static let name = "capture_flow_vision_analysis"

    static let schema: [String: Sendable] = [
        "type": "object",
        "additionalProperties": false,
        "required": [
            "resolved_card_type",
            "scene_title",
            "scene_summary",
            "user_intent_guess",
            "visible_text",
            "text_blocks",
            "visual_objects",
            "layout_description",
            "entities",
            "possible_actions",
            "constraints",
            "missing_info",
            "recommended_plan_title",
            "confidence_score",
            "evidence"
        ],
        "properties": [
            "resolved_card_type": [
                "type": "string",
                "enum": CardType.allCases.map(\.rawValue)
            ],
            "text_blocks": [
                "type": "array",
                "description": "Visual text groups reconstructed from nearby OCR fragments. Use this for user-facing display when the image contains documents, job descriptions, articles, requirements, receipts, or other text-heavy content.",
                "items": [
                    "type": "object",
                    "additionalProperties": false,
                    "required": ["title", "raw_fragments", "reconstructed_text", "confidence"],
                    "properties": [
                        "title": [
                            "type": ["string", "null"],
                            "description": "Visible section title or heading if available. Use null if there is no clear title."
                        ],
                        "raw_fragments": [
                            "type": "array",
                            "description": "Raw visible text fragments from the same visual block. These may preserve imperfect OCR-like splits and should not be shown directly as final user-facing insight text.",
                            "items": ["type": "string"]
                        ],
                        "reconstructed_text": [
                            "type": "string",
                            "description": "Cleaned, human-readable text reconstructed from raw_fragments. Merge broken lines, wrapped lists, and connector fragments. Do not leave orphan clauses or standalone fragments that only make sense with adjacent text."
                        ],
                        "confidence": [
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1
                        ]
                    ]
                ]
            ],
            "scene_title": ["type": "string"],
            "scene_summary": ["type": "string"],
            "user_intent_guess": ["type": "string"],
            "visible_text": [
                "type": "array",
                "description": "Cleaned, human-readable visible text. Do not include broken OCR fragments. Each item must be understandable by itself; merge wrapped lines, connector fragments, and comma-separated technology lists into complete sentences or coherent bullets.",
                "items": ["type": "string"]
            ],
            "visual_objects": [
                "type": "array",
                "items": ["type": "string"]
            ],
            "layout_description": ["type": "string"],
            "entities": [
                "type": "array",
                "items": [
                    "type": "object",
                    "additionalProperties": false,
                    "required": ["type", "label", "value", "confidence"],
                    "properties": [
                        "type": [
                            "type": "string",
                            "enum": VisionEntityType.allCases.map(\.rawValue)
                        ],
                        "label": ["type": "string"],
                        "value": ["type": "string"],
                        "confidence": ["type": "number", "minimum": 0, "maximum": 1]
                    ]
                ]
            ],
            "possible_actions": [
                "type": "array",
                "items": [
                    "type": "object",
                    "additionalProperties": false,
                    "required": ["title", "description", "action_type"],
                    "properties": [
                        "title": ["type": "string"],
                        "description": ["type": "string"],
                        "action_type": [
                            "type": "string",
                            "enum": VisionActionType.allCases.map(\.rawValue)
                        ]
                    ]
                ]
            ],
            "constraints": [
                "type": "array",
                "items": ["type": "string"]
            ],
            "missing_info": [
                "type": "array",
                "items": ["type": "string"]
            ],
            "recommended_plan_title": ["type": "string"],
            "confidence_score": ["type": "number", "minimum": 0, "maximum": 1],
            "evidence": [
                "type": "array",
                "items": ["type": "string"]
            ]
        ]
    ]
}

private extension Collection where Element: RawRepresentable, Element.RawValue == String {
    var promptList: String {
        map(\.rawValue).joined(separator: "\n")
    }
}
