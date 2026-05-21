import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    @State private var showsHeaderCreateButton = false
    @Environment(\.showDynamicIslandToast) private var showDynamicIslandToast
    private let onCreateCard: () -> Void
    private let onSelectCard: (SavedInsightCard) -> Void
    private let onOpenInbox: () -> Void
    private let onOpenSettings: () -> Void

    init(
        viewModel: HomeViewModel,
        onCreateCard: @escaping () -> Void = {},
        onSelectCard: @escaping (SavedInsightCard) -> Void = { _ in },
        onOpenInbox: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {}
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onCreateCard = onCreateCard
        self.onSelectCard = onSelectCard
        self.onOpenInbox = onOpenInbox
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

            if showsHeaderCreateButton {
                headerCreateButton
                    .transition(.scale(scale: 0.84).combined(with: .opacity))
            }

            inboxButton
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

    private var inboxButton: some View {
        Button(action: onOpenInbox) {
            Image(systemName: "tray.full.fill")
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
        .accessibilityLabel("Inbox")
    }

    private var headerCreateButton: some View {
        Button(action: onCreateCard) {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(CFColors.background)
                .frame(width: 32, height: 32)
                .background(CFColors.primaryOrange)
                .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.pill, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("New Insight")
    }

    private var actionButtons: some View {
        CFPrimaryButton("New Insight", systemImage: "plus.viewfinder", action: onCreateCard)
            .onScrollVisibilityChange(threshold: 0.01) { isVisible in
                updateHeaderCreateButtonVisibility(shouldShow: !isVisible)
            }
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

    private func updateHeaderCreateButtonVisibility(shouldShow: Bool) {
        guard showsHeaderCreateButton != shouldShow else {
            return
        }

        withAnimation(.easeInOut(duration: 0.18)) {
            showsHeaderCreateButton = shouldShow
        }
    }
}
