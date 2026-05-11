import SwiftUI

struct CardResultGenerationView: View {
    let context: VisionUnderstandingContext
    let cardGenerator: any CardGenerating
    let cardRepository: any CardRepository
    let reminderCreator: any ReminderCreating
    let calendarCreator: any CalendarCreating
    let onFinish: (ActionCard) -> Void
    let onCancel: () -> Void

    @State private var generatedResult: GeneratedCardResult?
    @State private var partial = CardGenerationPartial()
    @State private var errorMessage: String?
    @State private var generationRunID = UUID()

    var body: some View {
        Group {
            if let generatedResult {
                CardResultView(
                    viewModel: CardResultViewModel(
                        card: generatedResult.card,
                        generatedContent: generatedResult.content,
                        cardRepository: cardRepository,
                        reminderCreator: reminderCreator,
                        calendarCreator: calendarCreator
                    ),
                    onFinish: onFinish,
                    onCancel: onCancel
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                generationContent
                    .transition(.opacity)
            }
        }
        .animation(.snappy, value: generatedResult != nil)
        .task(id: generationRunID) {
            await streamCard()
        }
    }

    private var generationContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CFSpacing.xLarge) {
                summarySection

                if let errorMessage {
                    failureActions(errorMessage)
                }
            }
            .padding(CFSpacing.large)
        }
        .background(CFColors.background.ignoresSafeArea())
        .navigationTitle("Card Result")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                }
                .accessibilityLabel("Close")
            }
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: CFSpacing.medium) {
            HStack(spacing: CFSpacing.xSmall) {
                Image(systemName: "sparkles")
                    .imageScale(.small)

                Text("AI Summary")
            }
            .font(CFTypography.caption)
            .foregroundStyle(CFColors.orangeHighlight)

            if let title = partial.title, !title.isEmpty {
                Text(title)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(CFColors.textPrimary)
                    .contentTransition(.opacity)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(summaryText)
                .font(CFTypography.body)
                .foregroundStyle(CFColors.textSecondary)
                .lineSpacing(3)
                .contentTransition(.opacity)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(CFSpacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    CFColors.primaryOrange.opacity(0.18),
                    CFColors.secondarySurface
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CFCornerRadius.large, style: .continuous)
                .stroke(CFColors.primaryOrange.opacity(0.28), lineWidth: 1)
        }
        .animation(.easeOut, value: partial)
    }

    private var summaryText: String {
        if let summary = partial.summary, !summary.isEmpty {
            return summary
        }

        return "Generating summary from the analyzed image context..."
    }

    private func failureActions(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: CFSpacing.medium) {
            Text(message)
                .font(CFTypography.callout)
                .foregroundStyle(CFColors.destructive)

            CFPrimaryButton("Try Again", systemImage: "arrow.clockwise") {
                errorMessage = nil
                partial = CardGenerationPartial()
                generationRunID = UUID()
            }

            CFSecondaryButton("Back Home", systemImage: "house.fill") {
                onCancel()
            }
        }
    }

    private func streamCard() async {
        guard generatedResult == nil else {
            return
        }

        do {
            async let content = generatedContent()

            for try await event in cardGenerator.streamCard(from: context) {
                switch event {
                case .partial(let partial):
                    withAnimation(.easeOut) {
                        self.partial = partial
                    }
                case .completed(let card):
                    if partial.title == nil || partial.summary == nil {
                        withAnimation(.easeOut) {
                            partial = card.generationPartial
                        }
                    }

                    try? await Task.sleep(for: .milliseconds(450))
                    let generatedContent = await content
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                        generatedResult = GeneratedCardResult(card: card, content: generatedContent)
                    }
                }
            }
        } catch {
            errorMessage = "Unable to build this card: \(error.userFacingMessage)"
        }
    }

    private func generatedContent() async -> GeneratedCardContent {
        do {
            return try await cardGenerator.generateContent(from: context)
        } catch {
            return GeneratedCardContent.fallback(from: context)
        }
    }
}

private struct GeneratedCardResult {
    let card: ActionCard
    let content: GeneratedCardContent
}

private extension Error {
    var userFacingMessage: String {
        if let serviceError = self as? ServiceError {
            return serviceError.userFacingMessage
        }

        return String(describing: self)
    }
}

private extension ServiceError {
    var userFacingMessage: String {
        switch self {
        case .noImageProvided:
            "No image data was provided."
        case .unsupportedCardType(let cardType):
            "Unsupported card type: \(cardType.rawValue)."
        case .insufficientCredits:
            "No mock credits remaining."
        case .permissionDenied:
            "Permission denied."
        case .invalidGeneratedCard:
            "The generated card was missing required fields."
        case .unavailable(let message):
            message
        }
    }
}
