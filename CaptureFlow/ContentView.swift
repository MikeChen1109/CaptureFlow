//
//  ContentView.swift
//  CaptureFlow
//
//  Created by Mike Chen on 2026/5/11.
//

import SwiftUI

struct ContentView: View {
    let container: AppContainer
    @State private var path: [AppRoute] = []
    @State private var pendingAnalysisRequest: VisionAnalysisRequest?
    @State private var generatedCard: ActionCard?

    init(container: AppContainer = .prototype()) {
        self.container = container
    }

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(
                viewModel: HomeViewModel(container: container),
                onCreateCard: {
                    path.append(.capturePreview)
                },
                onSelectCard: { card in
                    path.append(.cardDetail(card.id))
                },
                onOpenSettings: {
                    path.append(.settings)
                }
            )
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .capturePreview:
                    CapturePreviewView { request in
                        pendingAnalysisRequest = request
                        path.append(.analysis)
                    }
                case .analysis:
                    if let pendingAnalysisRequest {
                        AnalysisLoadingView(
                            viewModel: AnalysisViewModel(container: container),
                            request: pendingAnalysisRequest
                        ) { card in
                            generatedCard = card
                            path.append(.cardResult(card.id))
                        }
                    } else {
                        unavailableScreen
                    }
                case .cardResult:
                    if let generatedCard {
                        CardResultView(
                            viewModel: CardResultViewModel(
                                card: generatedCard,
                                cardRepository: container.cardRepository,
                                reminderCreator: container.reminderCreator,
                                calendarCreator: container.calendarCreator
                            )
                        )
                    } else {
                        unavailableScreen
                    }
                case .cardDetail(let cardID):
                    CardDetailView(
                        viewModel: CardDetailViewModel(
                            cardID: cardID,
                            cardRepository: container.cardRepository
                        ),
                        onClose: {
                            path.removeLast()
                        }
                    )
                case .settings:
                    SettingsView(
                        viewModel: SettingsViewModel(
                            cardRepository: container.cardRepository,
                            creditProvider: container.creditProvider
                        )
                    )
                }
            }
        }
        .tint(CFColors.primaryOrange)
    }

    private var unavailableScreen: some View {
        CFEmptyStateView(
            title: "Coming soon",
            message: "This prototype screen is not connected yet.",
            systemImage: "hammer"
        )
        .padding(CFSpacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CFColors.background)
    }
}

#Preview {
    ContentView()
}
