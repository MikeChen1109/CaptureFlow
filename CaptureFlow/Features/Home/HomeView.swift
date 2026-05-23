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

            headerActions
        }
        .padding(.horizontal, CFSpacing.large)
        .padding(.top, CFSpacing.medium)
        .padding(.bottom, CFSpacing.large)
        .background(CFColors.background.opacity(0.68))
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

    private var headerActions: some View {
        HomeGlassActionBar {
            if showsHeaderCreateButton {
                HomeGlassActionButton(
                    systemImage: "plus",
                    accessibilityLabel: "New Insight",
                    action: onCreateCard
                )
                .transition(.scale(scale: 0.78).combined(with: .opacity))
            }

            HomeGlassActionButton(
                systemImage: "tray.full.fill",
                accessibilityLabel: "Inbox",
                action: onOpenInbox
            )

            HomeGlassActionButton(
                systemImage: "gearshape.fill",
                accessibilityLabel: "Settings",
                action: onOpenSettings
            )
        }
        .animation(.easeInOut(duration: 0.2), value: showsHeaderCreateButton)
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

private struct HomeGlassActionBar<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        HStack(spacing: 4) {
            content()
        }
        .padding(.horizontal, 8)
        .frame(height: 48)
        .background {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.18),
                                    Color.white.opacity(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blendMode(.screen)
                }
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.32), radius: 16, x: 0, y: 10)
        }
        .cfGlassCapsule()
    }
}

private struct HomeGlassActionButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(CFColors.textPrimary)
                .frame(width: 38, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
