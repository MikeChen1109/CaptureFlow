import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    @Environment(\.showDynamicIslandToast) private var showDynamicIslandToast
    private let onCreateCard: () -> Void
    private let onSelectCard: (SavedInsightCard) -> Void
    private let onOpenSettings: () -> Void

    init(
        viewModel: HomeViewModel,
        onCreateCard: @escaping () -> Void = {},
        onSelectCard: @escaping (SavedInsightCard) -> Void = { _ in },
        onOpenSettings: @escaping () -> Void = {}
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onCreateCard = onCreateCard
        self.onSelectCard = onSelectCard
        self.onOpenSettings = onOpenSettings
    }

    var body: some View {
        VStack(spacing: 0) {
            navigationHeader

            ScrollView {
                VStack(alignment: .leading, spacing: CFSpacing.xLarge) {
                    intro
                    errorBanner
                    actionButtons
                    content
                }
                .padding(.horizontal, CFSpacing.large)
                .padding(.top, CFSpacing.medium)
                .padding(.bottom, CFSpacing.xLarge)
            }
        }
        .captureFlowParticleBackground()
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.loadIfNeeded()
        }
        .onChange(of: viewModel.actionMessage) { _, newValue in
            guard let newValue else {
                return
            }

            showDynamicIslandToast(
                .success(
                    title: "Done",
                    message: newValue
                )
            )

            Task {
                try? await Task.sleep(for: .seconds(1.8))
                await MainActor.run {
                    guard viewModel.actionMessage == newValue else {
                        return
                    }

                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.clearActionMessage()
                    }
                }
            }
        }
        .tint(CFColors.primaryOrange)
    }

    private var navigationHeader: some View {
        HStack(alignment: .center, spacing: CFSpacing.medium) {
            Text("CaptureFlow")
                .font(CFTypography.largeTitle)
                .foregroundStyle(CFColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer(minLength: CFSpacing.medium)

            settingsButton
        }
        .padding(.horizontal, CFSpacing.large)
        .padding(.top, CFSpacing.medium)
        .padding(.bottom, CFSpacing.large)
        .background(CFColors.background.opacity(0.86))
    }

    private var intro: some View {
        Text("Turn captured context into useful insight cards.")
            .font(CFTypography.callout)
            .foregroundStyle(CFColors.textSecondary)
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .font(CFTypography.callout)
                .foregroundStyle(CFColors.destructive)
                .padding(CFSpacing.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(CFColors.destructive.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.medium, style: .continuous))
        }
    }

    private var settingsButton: some View {
        Button(action: onOpenSettings) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(CFColors.textPrimary)
                .frame(width: 32, height: 32)
                .background(CFColors.secondarySurface)
                .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.pill, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: CFCornerRadius.pill, style: .continuous)
                        .stroke(CFColors.border, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")
    }

    private var actionButtons: some View {
        CFPrimaryButton("New Insight", systemImage: "plus.viewfinder", action: onCreateCard)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.cards.isEmpty {
            CFEmptyStateView(
                title: "No insights yet",
                message: "Create a new insight from a photo or imported image.",
                systemImage: "rectangle.stack.badge.plus"
            )
        } else {
            VStack(alignment: .leading, spacing: CFSpacing.medium) {
                Text("Recent Insights")
                    .font(CFTypography.headline)
                    .foregroundStyle(CFColors.textPrimary)

                LazyVStack(spacing: CFSpacing.medium) {
                    ForEach(viewModel.cards) { card in
                        CardRowView(
                            card: card,
                            onSelect: {
                                onSelectCard(card)
                            }
                        )
                    }
                }
            }
        }
    }
}
