import SwiftUI

struct InboxView: View {
    @StateObject private var viewModel: InboxViewModel
    private let onSelectCard: (SavedInsightCard) -> Void

    init(
        viewModel: InboxViewModel,
        onSelectCard: @escaping (SavedInsightCard) -> Void = { _ in }
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onSelectCard = onSelectCard
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CFSpacing.xLarge) {
                statusFilter
                errorBanner
                content
            }
            .padding(.horizontal, CFSpacing.large)
            .padding(.top, CFSpacing.medium)
            .padding(.bottom, CFSpacing.xLarge)
        }
        .captureFlowParticleBackground()
        .navigationTitle("Inbox")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private var statusFilter: some View {
        HStack(spacing: CFSpacing.small) {
            ForEach(InboxStatusFilter.allCases) { filter in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        viewModel.selectedStatusFilter = filter
                    }
                } label: {
                    Text(filter.title)
                        .font(CFTypography.caption)
                        .foregroundStyle(viewModel.selectedStatusFilter == filter ? CFColors.background : CFColors.textPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(viewModel.selectedStatusFilter == filter ? CFColors.orangeHighlight : CFColors.secondarySurface)
                        .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.pill, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: CFCornerRadius.pill, style: .continuous)
                                .stroke(viewModel.selectedStatusFilter == filter ? CFColors.orangeHighlight : CFColors.border, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }
        }
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

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && !viewModel.hasLoaded {
            CFCardContainer {
                HStack(spacing: CFSpacing.medium) {
                    ProgressView()
                        .tint(CFColors.primaryOrange)

                    Text("Loading inbox")
                        .font(CFTypography.callout)
                        .foregroundStyle(CFColors.textSecondary)
                }
            }
        } else if viewModel.filteredCards.isEmpty {
            CFEmptyStateView(
                title: viewModel.emptyStateTitle,
                message: viewModel.emptyStateMessage,
                systemImage: "tray"
            )
        } else {
            LazyVStack(spacing: CFSpacing.medium) {
                ForEach(viewModel.filteredCards) { card in
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
