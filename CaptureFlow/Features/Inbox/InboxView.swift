import SwiftUI

struct InboxView: View {
    @StateObject private var viewModel: InboxViewModel
    @State private var isSearchExpanded = false
    @State private var isSearchActive = false
    @Environment(\.dismiss) private var dismiss
    private let onSelectCard: (SavedInsightCard) -> Void

    init(
        viewModel: InboxViewModel,
        onSelectCard: @escaping (SavedInsightCard) -> Void = { _ in }
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onSelectCard = onSelectCard
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CFSpacing.xLarge) {
            fixedHeader

            ScrollView {
                content
                    .padding(.horizontal, CFSpacing.large)
                    .padding(.bottom, CFSpacing.xLarge)
            }
        }
        .captureFlowParticleBackground()
        .toolbar(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private var fixedHeader: some View {
        VStack(alignment: .leading, spacing: CFSpacing.xLarge) {
            if !isSearchActive {
                navigationHeader
            }

            statusFilter
            errorBanner
        }
        .padding(.horizontal, CFSpacing.large)
        .padding(.top, CFSpacing.medium)
    }

    private var navigationHeader: some View {
        HStack(spacing: CFSpacing.medium) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(CFColors.textPrimary)
                    .frame(width: 34, height: 34)
                    .background(CFColors.secondarySurface)
                    .clipShape(.circle)
                    .overlay {
                        Circle()
                            .stroke(CFColors.border, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            Text("Inbox")
                .font(CFTypography.largeTitle)
                .foregroundStyle(CFColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer(minLength: CFSpacing.medium)
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var statusFilter: some View {
        InboxStatusFilterBar(
            items: InboxStatusFilter.allCases,
            selection: $viewModel.selectedStatusFilter,
            searchText: $viewModel.searchText,
            isSearchExpanded: $isSearchExpanded
        ) { isKeyboardActive in
            withAnimation(.snappy(duration: 0.24)) {
                isSearchActive = isKeyboardActive
            }
        }
        .padding(.horizontal, -CFSpacing.large)
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
        if shouldHideContentForEmptySearch {
            EmptyView()
        } else if viewModel.isLoading && !viewModel.hasLoaded {
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

    private var shouldHideContentForEmptySearch: Bool {
        isSearchExpanded && viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct InboxStatusFilterBar: View {
    let items: [InboxStatusFilter]
    @Binding var selection: InboxStatusFilter
    @Binding var searchText: String
    @Binding var isSearchExpanded: Bool
    let onSearchActivated: (Bool) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var viewSize: CGSize = .zero
    @FocusState private var isKeyboardActive: Bool

    var body: some View {
        let shouldAlignSearch = isSearchExpanded
        let viewWidth = viewSize.width

        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(items) { item in
                    itemView(item)
                }

                expandableSearchBar
            }
            .padding(.horizontal, 15)
            .visualEffect { content, proxy in
                let rect = proxy.frame(in: .scrollView)
                let maxX = max(rect.maxX - viewWidth, 0)

                return content
                    .offset(x: shouldAlignSearch ? -maxX : 0)
            }
        }
        .frame(height: 50)
        .scrollDisabled(isSearchExpanded)
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .animation(animation, value: selection)
        .animation(animation, value: isSearchExpanded)
        .animation(animation, value: isKeyboardActive)
        .onChange(of: isKeyboardActive) { _, newValue in
            onSearchActivated(newValue)
        }
        .onChange(of: isSearchExpanded) { _, newValue in
            if newValue {
                isKeyboardActive = true
            } else {
                isKeyboardActive = false
                searchText = ""
            }
        }
        .onGeometryChange(for: CGSize.self) {
            $0.size
        } action: { newValue in
            viewSize = newValue
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func itemView(_ item: InboxStatusFilter) -> some View {
        let isLast = items.last == item && isSearchExpanded

        ZStack {
            if isLast {
                Image(systemName: "circle.grid.2x2.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(searchControlTint)
                    .frame(width: 60, height: 45)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .contentShape(.capsule)
                    .onTapGesture {
                        collapseSearch()
                    }
                    .padding(.leading, 12)
                    .accessibilityLabel("Show filters")
            } else {
                Button {
                    withAnimation(animation) {
                        selection = item
                    }
                } label: {
                    Text(item.title)
                        .font(CFTypography.caption)
                        .foregroundStyle(foregroundTint(for: item))
                        .lineLimit(1)
                        .padding(.horizontal, 15)
                        .frame(height: 45)
                        .background(backgroundTint(for: item), in: .capsule)
                        .glassEffect(.regular.interactive(!isSearchExpanded), in: .capsule)
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .disabled(isSearchExpanded)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(selection == item ? .isSelected : [])
            }
        }
    }

    private var expandableSearchBar: some View {
        let fitSearchBarWidth = max(viewSize.width - 102, 180)

        return ZStack(alignment: .trailing) {
            HStack(spacing: 0) {
                Image(systemName: "magnifyingglass")
                    .font(.title3)
                    .foregroundStyle(searchControlTint)
                    .frame(width: isSearchExpanded ? 40 : 60)

                if isSearchExpanded {
                    TextField("Search inbox", text: $searchText)
                        .font(CFTypography.callout)
                        .foregroundStyle(CFColors.textPrimary)
                        .tint(CFColors.primaryOrange)
                        .focused($isKeyboardActive)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                        .accessibilityLabel("Search inbox")
                }
            }
            .padding(.leading, isSearchExpanded ? 5 : 0)
            .padding(.trailing, isSearchExpanded ? 15 : 0)
            .frame(height: 45)
            .clipShape(.capsule)
            .glassEffect(.regular.interactive(), in: .capsule)
            .contentShape(.capsule)
            .onTapGesture {
                guard !isSearchExpanded else {
                    return
                }

                withAnimation(animation) {
                    isSearchExpanded = true
                }
            }
            .padding(.trailing, isKeyboardActive ? 57 : 0)
            .zIndex(1)

            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(searchControlTint)
                .frame(width: 45, height: 45)
                .glassEffect(.regular.interactive(), in: .circle)
                .contentShape(.circle)
                .onTapGesture {
                    collapseSearch()
                }
                .opacity(isKeyboardActive ? 1 : 0)
                .offset(x: isKeyboardActive ? 0 : 70)
                .accessibilityLabel("Clear search")
                .zIndex(0)
        }
        .frame(width: isSearchExpanded ? fitSearchBarWidth : nil)
    }

    private var searchControlTint: Color {
        colorScheme == .dark ? CFColors.textPrimary : CFColors.background
    }

    private func foregroundTint(for item: InboxStatusFilter) -> Color {
        guard selection == item else {
            return CFColors.textPrimary
        }

        return colorScheme == .dark ? CFColors.background : CFColors.textPrimary
    }

    private func backgroundTint(for item: InboxStatusFilter) -> Color {
        guard selection == item else {
            return .clear
        }

        return colorScheme == .dark ? CFColors.textPrimary : CFColors.background
    }

    private func collapseSearch() {
        withAnimation(animation) {
            isSearchExpanded = false
        }
    }

    private var animation: Animation {
        .interpolatingSpring(duration: 0.3, bounce: 0, initialVelocity: 0)
    }
}
