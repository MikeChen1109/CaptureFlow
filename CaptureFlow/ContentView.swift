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
    @State private var isShowingNewCardFlow = false
    @State private var homeRefreshTrigger = UUID()
    @State private var completionMessage: String?

    init(
        container: AppContainer = .prototype()
    ) {
        self.container = container
    }

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(
                viewModel: HomeViewModel(container: container),
                refreshTrigger: homeRefreshTrigger,
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
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
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
        .fullScreenCover(isPresented: $isShowingNewCardFlow) {
            NewCardFlowView(container: container) { card in
                finishNewCardFlow(savedCard: card)
            }
        }
        .overlay(alignment: .top) {
            if let completionMessage {
                completionBanner(completionMessage)
                    .padding(.horizontal, CFSpacing.large)
                    .padding(.top, CFSpacing.large)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private func completionBanner(_ message: String) -> some View {
        HStack(spacing: CFSpacing.small) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(CFColors.success)

            Text(message)
                .font(CFTypography.callout.weight(.semibold))
                .foregroundStyle(CFColors.textPrimary)

            Spacer()
        }
        .padding(CFSpacing.medium)
        .background(CFColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CFCornerRadius.medium, style: .continuous)
                .stroke(CFColors.success.opacity(0.35), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 10)
    }

    private func finishNewCardFlow(savedCard: ActionCard?) {
        isShowingNewCardFlow = false

        guard let savedCard else {
            return
        }

        homeRefreshTrigger = UUID()
        showCompletionMessage("\(savedCard.type.displayName) saved to Inbox")
    }

    private func showCompletionMessage(_ message: String) {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            completionMessage = message
        }

        Task {
            try? await Task.sleep(for: .seconds(2.4))
            await MainActor.run {
                guard completionMessage == message else {
                    return
                }

                withAnimation(.easeInOut(duration: 0.2)) {
                    completionMessage = nil
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
