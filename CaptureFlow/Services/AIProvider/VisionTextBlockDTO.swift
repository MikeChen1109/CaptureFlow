//
//  VisionTextBlockDTO.swift
//  CaptureFlow
//
//  Created by Mike Chen on 2026/5/24.
//

struct VisionTextBlockDTO: Codable, Hashable, Sendable {
    var title: String?
    var rawFragments: [String]
    var reconstructedText: String
    var confidence: Double

    func toDomain() -> VisionTextBlock {
        VisionTextBlock(
            title: title,
            rawFragments: rawFragments,
            reconstructedText: reconstructedText,
            confidence: confidence
        )
    }
}
