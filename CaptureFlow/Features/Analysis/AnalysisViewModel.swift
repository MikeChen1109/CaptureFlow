import Combine
import Foundation

@MainActor
final class AnalysisViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case analyzing
        case completed
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var currentStepIndex = 0

    let steps = [
        "Reading image",
        "Understanding context"
    ]

    private let visionAnalyzer: any VisionAnalyzing

    init(
        visionAnalyzer: any VisionAnalyzing
    ) {
        self.visionAnalyzer = visionAnalyzer
    }

    convenience init(container: AppContainer) {
        self.init(
            visionAnalyzer: container.visionAnalyzer
        )
    }

    func analyze(_ request: VisionAnalysisRequest) async -> VisionUnderstandingContext? {
        state = .analyzing
        currentStepIndex = 0
        debugLog("Started analysis: \(request.debugSummary)")

        do {
            try await Task.sleep(for: .milliseconds(350))

            currentStepIndex = 1
            try await Task.sleep(for: .milliseconds(450))
            let context: VisionUnderstandingContext
            do {
                debugLog("Creating vision context")
                context = try await visionAnalyzer.analyze(request)
                debugLog("Created vision context: \(context.debugSummary)")
            } catch {
                debugLog("Vision context failed: \(error.debugSummary)")
                throw error
            }

            state = .completed
            return context
        } catch {
            debugLog("Analysis failed: \(error.debugSummary)")
            state = .failed("Analysis failed: \(error.userFacingDebugMessage)")
            return nil
        }
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[CaptureFlow][Analysis] \(message)")
        #endif
    }
}

private extension VisionAnalysisRequest {
    var debugSummary: String {
        [
            "id=\(id)",
            "selectedCardType=\(selectedCardType.rawValue)",
            "imageBytes=\(imageData?.count ?? 0)",
            "hasSourceImage=\(sourceImage != nil)",
            "createdAt=\(createdAt)"
        ].joined(separator: ", ")
    }
}

private extension VisionUnderstandingContext {
    var debugSummary: String {
        [
            "id=\(id)",
            "requested=\(requestedCardType.rawValue)",
            "resolved=\(resolvedCardType.rawValue)",
            "sceneTitle=\(sceneTitle)",
            "visibleText=\(visibleText)",
            "visualObjects=\(visualObjects)",
            "entities=\(entities.map { "\($0.type.rawValue):\($0.value)" })",
            "possibleActions=\(possibleActions.map { "\($0.actionType.rawValue):\($0.title)" })",
            "missingInfo=\(missingInfo)",
            "confidenceScore=\(confidenceScore)"
        ].joined(separator: ", ")
    }
}

private extension Error {
    var debugSummary: String {
        "\(type(of: self)): \(String(describing: self))"
    }

    var userFacingDebugMessage: String {
        if let serviceError = self as? ServiceError {
            return serviceError.debugMessage
        }

        return String(describing: self)
    }
}

private extension ServiceError {
    var debugMessage: String {
        switch self {
        case .noImageProvided:
            "No image data or source image was provided."
        case .unsupportedCardType(let cardType):
            "Unsupported card type: \(cardType.rawValue)."
        case .permissionDenied:
            "Permission denied."
        case .invalidGeneratedCard:
            "The generated card was missing required fields."
        case .unavailable(let message):
            message
        }
    }
}
