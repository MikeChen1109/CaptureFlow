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
        "Understanding context",
        "Building card"
    ]

    private let creditProvider: any CreditProviding
    private let visionAnalyzer: any VisionAnalyzing
    private let cardGenerator: any CardGenerating

    init(
        creditProvider: any CreditProviding,
        visionAnalyzer: any VisionAnalyzing,
        cardGenerator: any CardGenerating
    ) {
        self.creditProvider = creditProvider
        self.visionAnalyzer = visionAnalyzer
        self.cardGenerator = cardGenerator
    }

    convenience init(container: AppContainer) {
        self.init(
            creditProvider: container.creditProvider,
            visionAnalyzer: container.visionAnalyzer,
            cardGenerator: container.cardGenerator
        )
    }

    func analyze(_ request: VisionAnalysisRequest) async -> ActionCard? {
        state = .analyzing
        currentStepIndex = 0

        do {
            try await Task.sleep(for: .milliseconds(350))
            _ = try await creditProvider.consumeCredit(for: .analyzeImage)

            currentStepIndex = 1
            try await Task.sleep(for: .milliseconds(450))
            let context = try await visionAnalyzer.analyze(request)

            currentStepIndex = 2
            try await Task.sleep(for: .milliseconds(450))
            let card = try await cardGenerator.generateCard(from: context)

            state = .completed
            return card
        } catch ServiceError.insufficientCredits {
            state = .failed("No mock credits remaining.")
            return nil
        } catch {
            state = .failed("Analysis failed. Try another image.")
            return nil
        }
    }
}
