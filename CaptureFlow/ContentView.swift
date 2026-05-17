//
//  ContentView.swift
//  CaptureFlow
//
//  Created by Mike Chen on 2026/5/11.
//

import SwiftUI

struct ContentView: View {
    let container: AppContainer
    @StateObject private var homeViewModel: HomeViewModel
    @State private var path: [AppRoute] = []
    @State private var isShowingNewCardFlow = false
    @State private var isBootstrappingHome = true

    init(
        container: AppContainer = .prototype()
    ) {
        self.container = container
        _homeViewModel = StateObject(wrappedValue: HomeViewModel(container: container))
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if isBootstrappingHome {
                    HomeLoadingView()
                        .task {
                            await bootstrapHome()
                        }
                } else {
                    HomeView(
                        viewModel: homeViewModel,
                        onCreateCard: {
                            isShowingNewCardFlow = true
                        },
                        onSelectCard: { card in
                            path.append(.cardDetail(card.id))
                        },
                        onOpenSettings: {
                            path.append(.settings)
                        }
                    )
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .cardDetail(let cardID):
                    CardDetailView(
                        viewModel: CardDetailViewModel(
                            cardID: cardID,
                            cardRepository: container.cardRepository,
                            reminderCreator: container.reminderCreator,
                            calendarCreator: container.calendarCreator
                        ),
                        onCardUpdated: { updatedCard in
                            homeViewModel.applyUpdatedCard(updatedCard)
                        },
                        onCardDeleted: {
                            homeViewModel.removeCardLocally(cardID)
                            Task {
                                await homeViewModel.refresh()
                            }
                        },
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
        .environment(\.showDynamicIslandToast) { toast in
            showDynamicIslandToast(toast)
        }
        .dynamicIslandToastOverlay()
        .fullScreenCover(isPresented: $isShowingNewCardFlow) {
            NewCardFlowView(container: container) { card in
                finishNewCardFlow(savedCard: card)
            }
        }
    }

    private func finishNewCardFlow(savedCard: SavedInsightCard?) {
        isShowingNewCardFlow = false

        guard savedCard != nil else {
            return
        }

        Task {
            await homeViewModel.refresh()
        }
        showDynamicIslandToast(
            .success(
                title: "Saved",
                message: "Insight saved to Inbox"
            )
        )
    }

    private func bootstrapHome() async {
        guard isBootstrappingHome else {
            return
        }

        let start = Date()
        await homeViewModel.loadIfNeeded()

        let minimumDuration: TimeInterval = 0.65
        let elapsed = Date().timeIntervalSince(start)
        if elapsed < minimumDuration {
            try? await Task.sleep(for: .seconds(minimumDuration - elapsed))
        }

        await MainActor.run {
            withAnimation(.easeOut(duration: 0.28)) {
                isBootstrappingHome = false
            }
        }
    }

    private func showDynamicIslandToast(_ toast: DynamicIslandToast) {
        DynamicIslandToastCoordinator.shared.show(toast)
    }
}

#Preview {
    ContentView()
}
