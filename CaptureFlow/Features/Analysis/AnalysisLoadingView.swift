import SwiftUI

struct AnalysisLoadingView: View {
    @StateObject private var viewModel: AnalysisViewModel
    @State private var analysisRunID = UUID()
    let request: VisionAnalysisRequest
    let onCompleted: (VisionUnderstandingContext) -> Void
    let onChangeImage: () -> Void
    let onCancel: () -> Void

    init(
        viewModel: AnalysisViewModel,
        request: VisionAnalysisRequest,
        onCompleted: @escaping (VisionUnderstandingContext) -> Void,
        onChangeImage: @escaping () -> Void = {},
        onCancel: @escaping () -> Void = {}
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.request = request
        self.onCompleted = onCompleted
        self.onChangeImage = onChangeImage
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(spacing: CFSpacing.xLarge) {
            Spacer()

            CFCardContainer {
                VStack(alignment: .leading, spacing: CFSpacing.xLarge) {
                    VStack(alignment: .leading, spacing: CFSpacing.small) {
                        Text("Analyzing")
                            .font(CFTypography.title)
                            .foregroundStyle(CFColors.textPrimary)

                        Text("Prototype mode: analysis is simulated locally.")
                            .font(CFTypography.callout)
                            .foregroundStyle(CFColors.textSecondary)
                    }

                    CFLoadingStepsView(
                        steps: viewModel.steps,
                        currentStepIndex: viewModel.currentStepIndex
                    )

                    if case .failed(let message) = viewModel.state {
                        failureActions(message)
                    }
                }
            }

            Spacer()
        }
        .padding(CFSpacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .captureFlowParticleBackground()
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
        .task(id: analysisRunID) {
            guard viewModel.state != .analyzing, viewModel.state != .completed else {
                return
            }

            if let card = await viewModel.analyze(request) {
                onCompleted(card)
            }
        }
    }

    private func failureActions(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: CFSpacing.medium) {
            Text(message)
                .font(CFTypography.callout)
                .foregroundStyle(CFColors.destructive)

            CFPrimaryButton("Try Again", systemImage: "arrow.clockwise") {
                analysisRunID = UUID()
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
