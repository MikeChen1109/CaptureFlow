import Foundation
import Testing
@testable import CaptureFlow

struct VisionAnalysisPromptProviderTests {
    @Test func defaultPromptIncludesRequestedTypeEnumsAndJSONRules() {
        let prompt = DefaultVisionAnalysisPromptProvider().prompt(
            for: VisionAnalysisPromptRequest(requestedCardType: .receipt)
        )

        #expect(prompt.developerMessage.contains("vision understanding engine"))
        #expect(prompt.developerMessage.contains("Output JSON only"))
        #expect(prompt.userMessage.contains("requested_card_type: receipt"))
        #expect(prompt.userMessage.contains("Allowed CardType values"))
        #expect(prompt.userMessage.contains("appScreen"))
        #expect(prompt.userMessage.contains("resolved_card_type"))
        #expect(prompt.userMessage.contains("action_type"))
    }

    @Test func responseSchemaUsesSnakeCaseDTOKeys() throws {
        let properties = try #require(
            VisionAnalysisResponseSchema.schema["properties"] as? [String: Sendable]
        )

        #expect(properties["resolved_card_type"] != nil)
        #expect(properties["missing_info"] != nil)
        #expect(properties["possible_actions"] != nil)
        #expect(properties["resolvedCardType"] == nil)
    }

    @Test func visionAnalysisDTODecodesSnakeCaseTextBlocks() throws {
        let json = """
        {
          "resolved_card_type": "note",
          "scene_title": "Release notes",
          "scene_summary": "A text-heavy screenshot.",
          "user_intent_guess": "Save the important details.",
          "visible_text": ["Ship the update today."],
          "text_blocks": [
            {
              "title": "Tasks",
              "raw_fragments": ["Ship the", "update today."],
              "reconstructed_text": "Ship the update today.",
              "confidence": 0.9
            }
          ],
          "visual_objects": ["document"],
          "layout_description": "Single column text.",
          "entities": [],
          "possible_actions": [
            {
              "title": "Save note",
              "description": "Keep the task text.",
              "action_type": "save"
            }
          ],
          "constraints": [],
          "missing_info": [],
          "recommended_plan_title": "Save note",
          "confidence_score": 0.85,
          "evidence": ["Visible task text"]
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let dto = try decoder.decode(VisionAnalysisDTO.self, from: Data(json.utf8))

        #expect(dto.textBlocks.first?.rawFragments == ["Ship the", "update today."])
        #expect(dto.textBlocks.first?.reconstructedText == "Ship the update today.")
        #expect(dto.possibleActions.first?.actionType == "save")
    }
}
