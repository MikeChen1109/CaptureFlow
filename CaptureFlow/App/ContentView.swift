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
    @StateObject private var inboxViewModel: InboxViewModel
    @State private var path: [AppRoute] = []
    @State private var isShowingNewCardFlow = false
    @State private var isBootstrappingHome = true

    init(
        container: AppContainer = .local()
    ) {
        self.container = container
        _homeViewModel = StateObject(wrappedValue: HomeViewModel(container: container))
        _inboxViewModel = StateObject(wrappedValue: InboxViewModel(container: container))
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
                        onOpenInbox: {
                            path.append(.inbox)
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
                            inboxViewModel.applyUpdatedCard(updatedCard)
                        },
                        onCardDeleted: {
                            homeViewModel.removeCardLocally(cardID)
                            inboxViewModel.removeCardLocally(cardID)
                            Task {
                                await homeViewModel.refresh()
                                await inboxViewModel.refresh()
                            }
                        },
                        onClose: {
                            path.removeLast()
                        }
                    )
                case .inbox:
                    InboxView(
                        viewModel: inboxViewModel,
                        onSelectCard: { card in
                            path.append(.cardDetail(card.id))
                        }
                    )
                case .settings:
                    SettingsView(
                        viewModel: SettingsViewModel(
                            cardRepository: container.cardRepository
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
            await inboxViewModel.refresh()
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
