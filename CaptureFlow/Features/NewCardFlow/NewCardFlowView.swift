import SwiftUI

struct NewCardFlowView: View {
    private enum Route: Hashable {
        case analysis(VisionAnalysisRequest)
        case cardResult(VisionUnderstandingContext)
    }

    let container: AppContainer
    let onFinish: (ActionCard?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var path: [Route] = []

    init(
        container: AppContainer,
        onFinish: @escaping (ActionCard?) -> Void
    ) {
        self.container = container
        self.onFinish = onFinish
    }

    var body: some View {
        NavigationStack(path: $path) {
            CapturePreviewView(
                onAnalyze: { request in
                    path.append(.analysis(request))
                },
                onCancel: {
                    finishFlow()
                }
            )
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .analysis(let request):
                    AnalysisLoadingView(
                        viewModel: AnalysisViewModel(container: container),
                        request: request,
                        onCompleted: { context in
                            path = [.cardResult(context)]
                        },
                        onChangeImage: {
                            path.removeAll()
                        },
                        onCancel: {
                            finishFlow()
                        }
                    )
                case .cardResult(let context):
                    CardResultGenerationView(
                        context: context,
                        cardGenerator: container.cardGenerator,
                        cardRepository: container.cardRepository,
                        reminderCreator: container.reminderCreator,
                        calendarCreator: container.calendarCreator,
                        onFinish: { savedCard in
                            finishFlow(savedCard: savedCard)
                        },
                        onCancel: {
                            finishFlow()
                        }
                    )
                }
            }
        }
        .tint(CFColors.primaryOrange)
    }

    private func finishFlow(savedCard: ActionCard? = nil) {
        onFinish(savedCard)
        dismiss()
    }
}

#Preview {
    NewCardFlowView(container: .prototype(), onFinish: { _ in })
}
