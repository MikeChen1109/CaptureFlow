import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
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
        .background(CFColors.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.loadIfNeeded()
        }
        .overlay(alignment: .top) {
            if let actionMessage = viewModel.actionMessage {
                ActionToast(message: actionMessage)
                    .padding(.horizontal, CFSpacing.large)
                    .padding(.top, CFSpacing.large)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onChange(of: viewModel.actionMessage) { _, newValue in
            guard let newValue else {
                return
            }

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
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: viewModel.actionMessage)
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

            HStack(spacing: CFSpacing.small) {
                creditsBadge
                settingsButton
            }
        }
        .padding(.horizontal, CFSpacing.large)
        .padding(.top, CFSpacing.medium)
        .padding(.bottom, CFSpacing.large)
        .background(CFColors.background)
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

    private var creditsBadge: some View {
        HStack(spacing: CFSpacing.xSmall) {
            Image(systemName: "bolt.fill")
                .imageScale(.small)

            Text(creditsText)
                .lineLimit(1)
        }
        .font(CFTypography.caption)
        .foregroundStyle(CFColors.orangeHighlight)
        .padding(.horizontal, CFSpacing.medium)
        .frame(height: 32)
        .background(CFColors.primaryOrange.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.pill, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CFCornerRadius.pill, style: .continuous)
                .stroke(CFColors.primaryOrange.opacity(0.32), lineWidth: 1)
        }
    }

    private var creditsText: String {
        guard let creditBalance = viewModel.creditBalance else {
            return "-- credits"
        }

        return "\(creditBalance.remaining) credits"
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
                            isCreatingReminder: viewModel.creatingReminderCardID == card.id,
                            isCreatingCalendar: viewModel.creatingCalendarCardID == card.id,
                            onSelect: {
                                onSelectCard(card)
                            },
                            onCreateReminder: {
                                Task {
                                    await viewModel.createReminder(for: card.id)
                                }
                            },
                            onCreateCalendar: {
                                Task {
                                    await viewModel.createCalendarEvent(for: card.id)
                                }
                            }
                        )
                    }
                }
            }
        }
    }
}

private struct ActionToast: View {
    let message: String

    var body: some View {
        HStack(spacing: CFSpacing.small) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(CFColors.success)

            Text(message)
                .font(CFTypography.callout.weight(.semibold))
                .foregroundStyle(CFColors.textPrimary)

            Spacer(minLength: 0)
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
}
