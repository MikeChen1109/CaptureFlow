import SwiftUI

struct CardResultGenerationView: View {
    private enum FlowPhase {
        case loading
        case failed
        case revealing
        case ready
    }

    private enum LoadingStep: Int {
        case readingImage
        case understandingContext
        case generatingCard

        static let allTitles = [
            "Reading image",
            "Understanding context",
            "Generating action card"
        ]
    }

    let request: VisionAnalysisRequest
    let cardGenerator: any CardGenerating
    let cardRepository: any CardRepository
    let reminderCreator: any ReminderCreating
    let calendarCreator: any CalendarCreating
    let onFinish: (ActionCard) -> Void
    let onChangeImage: () -> Void
    let onCancel: () -> Void

    @StateObject private var analysisViewModel: AnalysisViewModel
    @StateObject private var viewModel: CardResultViewModel
    @State private var flowAttemptID = UUID()
    @State private var phase: FlowPhase = .loading
    @State private var loadingStepIndex = LoadingStep.readingImage.rawValue
    @State private var loadingErrorMessage: String?
    @State private var revealedSectionCount = 0

    init(
        request: VisionAnalysisRequest,
        creditProvider: any CreditProviding,
        visionAnalyzer: any VisionAnalyzing,
        cardGenerator: any CardGenerating,
        cardRepository: any CardRepository,
        reminderCreator: any ReminderCreating,
        calendarCreator: any CalendarCreating,
        onFinish: @escaping (ActionCard) -> Void,
        onChangeImage: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.request = request
        self.cardGenerator = cardGenerator
        self.cardRepository = cardRepository
        self.reminderCreator = reminderCreator
        self.calendarCreator = calendarCreator
        self.onFinish = onFinish
        self.onChangeImage = onChangeImage
        self.onCancel = onCancel

        _analysisViewModel = StateObject(
            wrappedValue: AnalysisViewModel(
                creditProvider: creditProvider,
                visionAnalyzer: visionAnalyzer
            )
        )

        _viewModel = StateObject(
            wrappedValue: CardResultViewModel(
                card: Self.placeholderCard(),
                cardRepository: cardRepository,
                reminderCreator: reminderCreator,
                calendarCreator: calendarCreator
            )
        )
    }

    var body: some View {
        ZStack {
            CardResultView(
                viewModel: viewModel,
                onFinish: onFinish,
                onCancel: visibleOnCancel,
                onRetry: retryFlow,
                revealedSectionCount: revealedSectionCount,
                isResultFullyRevealed: phase == .ready
            )
            .opacity(phase == .revealing || phase == .ready ? 1 : 0)
            .scaleEffect(phase == .revealing ? 0.996 : 1)
            .allowsHitTesting(phase == .ready)

            if phase == .loading || phase == .failed {
                UnifiedGenerationLoadingView(
                    currentStepIndex: loadingStepIndex,
                    steps: LoadingStep.allTitles,
                    errorMessage: loadingErrorMessage,
                    onRetry: retryFlow,
                    onChangeImage: onChangeImage,
                    onCancel: onCancel
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: phase)
        .task(id: flowAttemptID) {
            await runPipeline()
        }
        .onChange(of: analysisViewModel.currentStepIndex) { _, newValue in
            guard phase == .loading else { return }
            loadingStepIndex = max(
                LoadingStep.readingImage.rawValue,
                min(newValue, LoadingStep.understandingContext.rawValue)
            )
        }
    }

    private var visibleOnCancel: (() -> Void)? {
        phase == .ready ? onCancel : nil
    }

    private func runPipeline() async {
        phase = .loading
        loadingErrorMessage = nil
        loadingStepIndex = LoadingStep.readingImage.rawValue
        revealedSectionCount = 0

        guard let context = await analysisViewModel.analyze(request) else {
            if case .failed(let message) = analysisViewModel.state {
                loadingErrorMessage = message
            } else {
                loadingErrorMessage = "Analysis failed."
            }
            phase = .failed
            return
        }

        loadingStepIndex = LoadingStep.generatingCard.rawValue

        do {
            var completedPayload: (card: ActionCard, content: GeneratedCardContent)?
            for try await event in cardGenerator.streamGeneratedContent(from: context) {
                switch event {
                case .partialContent:
                    continue
                case .completed(let card, let content):
                    completedPayload = (card: card, content: content)
                }
            }

            guard let completedPayload else {
                throw ServiceError.invalidGeneratedCard
            }

            viewModel.completeGeneration(card: completedPayload.card, content: completedPayload.content)
            await revealContentTopToBottom()
        } catch {
            viewModel.failGeneration(error)
            loadingErrorMessage = "Unable to build this card: \(error.userFacingMessage)"
            phase = .failed
        }
    }

    private func revealContentTopToBottom() async {
        withAnimation(.easeOut(duration: 0.2)) {
            phase = .revealing
        }
        let totalSections = viewModel.sectionStates.count

        for nextVisibleCount in 1...totalSections {
            withAnimation(.spring(response: 0.44, dampingFraction: 0.83, blendDuration: 0.1)) {
                revealedSectionCount = nextVisibleCount
            }
            try? await Task.sleep(for: .milliseconds(135))
        }

        withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
            phase = .ready
        }
    }

    private func retryFlow() {
        viewModel.resetForRetry(with: Self.placeholderCard())
        loadingErrorMessage = nil
        revealedSectionCount = 0
        phase = .loading
        flowAttemptID = UUID()
    }

    private static func placeholderCard() -> ActionCard {
        .note(
            NoteCard(
                metadata: CardMetadata(
                    confidence: .medium,
                    confidenceScore: 0.6
                ),
                title: "Generating...",
                summary: ""
            )
        )
    }
}

private struct UnifiedGenerationLoadingView: View {
    @State private var pulse = false

    let currentStepIndex: Int
    let steps: [String]
    let errorMessage: String?
    let onRetry: () -> Void
    let onChangeImage: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    CFColors.background,
                    CFColors.background,
                    CFColors.secondarySurface
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: CFSpacing.xLarge) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(CFColors.primaryOrange.opacity(0.18))
                        .frame(width: pulse ? 146 : 118, height: pulse ? 146 : 118)
                        .blur(radius: 8)

                    RoundedRectangle(cornerRadius: CFCornerRadius.xLarge, style: .continuous)
                        .fill(CFColors.surface)
                        .frame(width: 94, height: 94)
                        .overlay {
                            RoundedRectangle(cornerRadius: CFCornerRadius.xLarge, style: .continuous)
                                .stroke(CFColors.border, lineWidth: 1)
                        }

                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(CFColors.orangeHighlight)
                }
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)

                CFCardContainer {
                    VStack(alignment: .leading, spacing: CFSpacing.xLarge) {
                        VStack(alignment: .leading, spacing: CFSpacing.small) {
                            Text("Analyzing & Building Card")
                                .font(CFTypography.title)
                                .foregroundStyle(CFColors.textPrimary)

                            Text("Prototype mode: local analysis and generation.")
                                .font(CFTypography.callout)
                                .foregroundStyle(CFColors.textSecondary)
                        }

                        CFLoadingStepsView(
                            steps: steps,
                            currentStepIndex: max(0, min(currentStepIndex, steps.count - 1))
                        )

                        if let errorMessage {
                            failureActions(message: errorMessage)
                        }
                    }
                }
                .padding(.horizontal, CFSpacing.large)

                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                }
                .accessibilityLabel("Close")
            }
        }
        .task {
            pulse = true
        }
    }

    private func failureActions(message: String) -> some View {
        VStack(alignment: .leading, spacing: CFSpacing.medium) {
            Text(message)
                .font(CFTypography.callout)
                .foregroundStyle(CFColors.destructive)

            CFPrimaryButton("Try Again", systemImage: "arrow.clockwise") {
                onRetry()
            }

            HStack(spacing: CFSpacing.medium) {
                CFSecondaryButton("Change Image", systemImage: "photo.on.rectangle") {
                    onChangeImage()
                }

                CFSecondaryButton("Back Home", systemImage: "house.fill") {
                    onCancel()
                }
            }
        }
    }
}

private extension Error {
    var userFacingMessage: String {
        if let serviceError = self as? ServiceError {
            return serviceError.message
        }

        return localizedDescription
    }
}

private extension ServiceError {
    var message: String {
        switch self {
        case .noImageProvided:
            "No image was found."
        case .unsupportedCardType(let cardType):
            "Unsupported card type: \(cardType.rawValue)."
        case .insufficientCredits:
            "No mock credits remaining."
        case .permissionDenied:
            "Permission denied."
        case .invalidGeneratedCard:
            "Generated output was invalid."
        case .unavailable(let message):
            message
        }
    }
}
