import Foundation

struct MockVisionAnalyzer: VisionAnalyzing {
    func analyze(_ request: VisionAnalysisRequest) async throws -> MockCloudVisionContext {
        guard request.imageData != nil || request.sourceImage != nil else {
            throw ServiceError.noImageProvided
        }

        return context(
            for: request.selectedCardType,
            sourceImage: request.sourceImage
        )
    }

    private func context(
        for selectedCardType: CardType,
        sourceImage: CardSourceImage?
    ) -> MockCloudVisionContext {
        let resolvedCardType = resolvedType(for: selectedCardType)

        switch resolvedCardType {
        case .auto:
            return context(for: .shopping, sourceImage: sourceImage)
        case .reminder:
            return MockCloudVisionContext(
                requestedCardType: selectedCardType,
                resolvedCardType: .reminder,
                sourceImage: sourceImage,
                detectedText: [
                    "Design meetup",
                    "2026-06-15",
                    "19:30",
                    "Taipei"
                ],
                detectedObjects: ["event poster", "date", "location"],
                dateCandidates: ["2026-06-15"],
                timeCandidates: ["19:30"],
                locationCandidates: ["Taipei"],
                suggestedAction: "Create reminder for the design meetup",
                confidenceScore: 0.88
            )
        case .calendar:
            return MockCloudVisionContext(
                requestedCardType: selectedCardType,
                resolvedCardType: .calendar,
                sourceImage: sourceImage,
                detectedText: [
                    "Product Review Sync",
                    "2026-06-18",
                    "14:00-15:00",
                    "Taipei 101 Meeting Room"
                ],
                detectedObjects: ["meeting agenda", "calendar date", "time range"],
                dateCandidates: ["2026-06-18"],
                timeCandidates: ["14:00", "15:00"],
                locationCandidates: ["Taipei 101 Meeting Room"],
                suggestedAction: "Create calendar event",
                confidenceScore: 0.91
            )
        case .note:
            return MockCloudVisionContext(
                requestedCardType: selectedCardType,
                resolvedCardType: .note,
                sourceImage: sourceImage,
                detectedText: [
                    "Launch checklist",
                    "Polish onboarding",
                    "Test import flow",
                    "Prepare demo script"
                ],
                detectedObjects: ["whiteboard", "sticky notes", "handwritten tasks"],
                suggestedAction: "Save whiteboard notes and todos",
                confidenceScore: 0.82
            )
        case .shopping:
            return MockCloudVisionContext(
                requestedCardType: selectedCardType,
                resolvedCardType: .shopping,
                sourceImage: sourceImage,
                detectedText: [
                    "Orange Mechanical Keyboard",
                    "NT$2,490",
                    "Limited time discount"
                ],
                detectedObjects: ["keyboard", "price tag", "discount label"],
                priceCandidates: ["NT$2,490"],
                suggestedAction: "Create purchase reminder",
                confidenceScore: 0.9
            )
        case .job:
            return MockCloudVisionContext(
                requestedCardType: selectedCardType,
                resolvedCardType: .job,
                sourceImage: sourceImage,
                detectedText: [
                    "Capture Labs",
                    "iOS Engineer",
                    "SwiftUI, iOS, AI features",
                    "Follow up recruiter"
                ],
                detectedObjects: ["job post", "company name", "skill list"],
                companyCandidates: ["Capture Labs"],
                skillCandidates: ["SwiftUI", "iOS", "AI features"],
                suggestedAction: "Follow up recruiter",
                confidenceScore: 0.86
            )
        }
    }

    private func resolvedType(for selectedCardType: CardType) -> CardType {
        switch selectedCardType {
        case .auto:
            .shopping
        default:
            selectedCardType
        }
    }
}
