import SwiftUI

struct AnalysisLoadingView: View {
    @StateObject private var viewModel: AnalysisViewModel
    let request: VisionAnalysisRequest
    let onCompleted: (ActionCard) -> Void

    init(
        viewModel: AnalysisViewModel,
        request: VisionAnalysisRequest,
        onCompleted: @escaping (ActionCard) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.request = request
        self.onCompleted = onCompleted
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
                        Text(message)
                            .font(CFTypography.callout)
                            .foregroundStyle(CFColors.destructive)
                    }
                }
            }

            Spacer()
        }
        .padding(CFSpacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CFColors.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(viewModel.state == .analyzing)
        .task {
            guard case .idle = viewModel.state else {
                return
            }

            if let card = await viewModel.analyze(request) {
                onCompleted(card)
            }
        }
    }
}
