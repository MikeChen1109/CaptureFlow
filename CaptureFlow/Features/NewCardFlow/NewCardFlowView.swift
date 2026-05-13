import SwiftUI

struct NewCardFlowView: View {
    private enum Route: Hashable {
        case cardResult(VisionAnalysisRequest)
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
                    path.append(.cardResult(request))
                },
                onCancel: {
                    finishFlow()
                }
            )
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .cardResult(let request):
                    CardResultGenerationView(
                        request: request,
                        creditProvider: container.creditProvider,
                        visionAnalyzer: container.visionAnalyzer,
                        cardGenerator: container.cardGenerator,
                        cardRepository: container.cardRepository,
                        reminderCreator: container.reminderCreator,
                        calendarCreator: container.calendarCreator,
                        onFinish: { savedCard in
                            finishFlow(savedCard: savedCard)
                        },
                        onChangeImage: {
                            path.removeAll()
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
