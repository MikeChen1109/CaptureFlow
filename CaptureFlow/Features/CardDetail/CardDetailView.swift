import SwiftUI

struct CardDetailView: View {
    @StateObject private var viewModel: CardDetailViewModel
    @State private var previewSourceImage: CardSourceImage?
    @State private var isPresentingDeleteConfirmation = false
    let onCardUpdated: (SavedInsightCard) -> Void
    let onCardDeleted: () -> Void
    let onClose: () -> Void

    private let sectionSpacing = CFSpacing.large

    init(
        viewModel: CardDetailViewModel,
        onCardUpdated: @escaping (SavedInsightCard) -> Void = { _ in },
        onCardDeleted: @escaping () -> Void = {},
        onClose: @escaping () -> Void = {}
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onCardUpdated = onCardUpdated
        self.onCardDeleted = onCardDeleted
        self.onClose = onClose
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                content
            }
            .padding(CFSpacing.large)
        }
        .captureFlowParticleBackground()
        .navigationTitle("Insight Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if viewModel.card != nil {
                    overflowMenu
                }
            }
        }
        .task {
            await viewModel.load()
        }
        .sheet(item: $previewSourceImage) { preview in
            SourceImagePreviewView(sourceImage: preview)
        }
        .confirmationDialog(
            "Delete this insight?",
            isPresented: $isPresentingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Insight", role: .destructive) {
                Task {
                    await deleteCard()
                }
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the card from your inbox.")
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            CardDetailLoadingView()
        } else if let card = viewModel.card {
            header(card)
            sourceSection(card)
            insightSections(card)
            CustomFieldsSection(
                customFields: viewModel.customFields,
                onAddCustomField: { fieldType, value in
                    viewModel.addCustomField(type: fieldType, value: value)
                },
                onRemoveCustomField: { fieldID in
                    viewModel.removeCustomField(id: fieldID)
                },
                onRestoreCustomField: { removedField in
                    viewModel.restoreCustomField(removedField)
                }
            )
            actions
        } else {
            CFEmptyStateView(
                title: "Insight unavailable",
                message: viewModel.errorMessage ?? "This insight may have been deleted.",
                systemImage: "exclamationmark.triangle"
            )
        }
    }

    private func header(_ card: SavedInsightCard) -> some View {
        CFCardContainer {
            VStack(alignment: .leading, spacing: CFSpacing.large) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: CFSpacing.small) {
                        Text("Insight")
                            .font(CFTypography.caption)
                            .foregroundStyle(CFColors.orangeHighlight)

                        Text(card.title)
                            .font(CFTypography.title)
                            .foregroundStyle(CFColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func sourceSection(_ card: SavedInsightCard) -> some View {
        SourceImageSectionView(card: card, previewSourceImage: $previewSourceImage)
    }

    private func insightSections(_ card: SavedInsightCard) -> some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            ForEach(card.insight.sections.sorted { $0.priority < $1.priority }) { section in
                InsightSectionView(section: section)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: sectionSpacing) {
            if viewModel.showsExternalActions {
                HStack(spacing: CFSpacing.medium) {
                    if viewModel.showsReminderAction {
                        CFSecondaryButton(
                            viewModel.didCreateReminder
                                ? "Reminder Created"
                                : viewModel.isCreatingReminder ? "Creating..." : "Add Reminder",
                            systemImage: viewModel.didCreateReminder ? "checkmark.circle.fill" : "bell.badge.fill",
                            tone: viewModel.didCreateReminder ? .success : .normal,
                            isDisabled: !viewModel.canCreateReminder || viewModel.didCreateReminder || viewModel.isArchiving || viewModel.isDeleting
                        ) {
                            Task {
                                if let updatedCard = await viewModel.createReminder() {
                                    onCardUpdated(updatedCard)
                                }
                            }
                        }
                    }

                    if viewModel.showsCalendarAction {
                        CFSecondaryButton(
                            viewModel.didCreateCalendar
                                ? "Calendar Created"
                                : viewModel.isCreatingCalendar ? "Creating..." : "Add Calendar",
                            systemImage: viewModel.didCreateCalendar ? "checkmark.circle.fill" : "calendar.badge.plus",
                            tone: viewModel.didCreateCalendar ? .success : .normal,
                            isDisabled: !viewModel.canCreateCalendar || viewModel.didCreateCalendar || viewModel.isArchiving || viewModel.isDeleting
                        ) {
                            Task {
                                if let updatedCard = await viewModel.createCalendarEvent() {
                                    onCardUpdated(updatedCard)
                                }
                            }
                        }
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(CFTypography.callout)
                    .foregroundStyle(CFColors.destructive)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var overflowMenu: some View {
        Menu {
            Button {
                viewModel.copyMarkdown()
            } label: {
                Label(
                    viewModel.didCopyMarkdown ? "Markdown Copied" : "Copy Markdown",
                    systemImage: viewModel.didCopyMarkdown ? "checkmark" : "doc.on.doc.fill"
                )
            }

            Button {
                Task {
                    await archiveCard()
                }
            } label: {
                Label(
                    viewModel.isArchiving ? "Archiving..." : "Archive",
                    systemImage: "archivebox.fill"
                )
            }
            .disabled(viewModel.isArchiving || viewModel.isDeleting)

            Button(role: .destructive) {
                isPresentingDeleteConfirmation = true
            } label: {
                Label(
                    viewModel.isDeleting ? "Deleting..." : "Delete",
                    systemImage: "trash.fill"
                )
            }
            .disabled(viewModel.isArchiving || viewModel.isDeleting)
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(CFColors.textPrimary)
        }
        .accessibilityLabel("More actions")
    }

    private func archiveCard() async {
        if let updatedCard = await viewModel.archive() {
            onCardUpdated(updatedCard)
            onClose()
        }
    }

    private func deleteCard() async {
        if await viewModel.delete() {
            onCardDeleted()
            onClose()
        }
    }

}

private struct CardDetailLoadingView: View {
    @State private var pulse = false
    @AppStorage(GenerationPreferences.Keys.enablesMotionEffects) private var enablesMotionEffects = true

    var body: some View {
        VStack(alignment: .leading, spacing: CFSpacing.large) {
            loadingHero
            titleSkeleton
            sourceSkeleton
            detailSkeleton
        }
        .task {
            pulse = enablesMotionEffects
        }
    }

    private var loadingHero: some View {
        CFCardContainer {
            HStack(spacing: CFSpacing.medium) {
                ZStack {
                    Circle()
                        .fill(CFColors.primaryOrange.opacity(pulse ? 0.22 : 0.1))
                        .frame(width: pulse ? 54 : 44, height: pulse ? 54 : 44)

                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(CFColors.orangeHighlight)
                }
                .frame(width: 58, height: 58)
                .animation(
                    enablesMotionEffects ? .easeInOut(duration: 1.05).repeatForever(autoreverses: true) : nil,
                    value: pulse
                )

                VStack(alignment: .leading, spacing: CFSpacing.xSmall) {
                    Text("Opening insight")
                        .font(CFTypography.headline)
                        .foregroundStyle(CFColors.textPrimary)

                    Text("Preparing the saved details.")
                        .font(CFTypography.callout)
                        .foregroundStyle(CFColors.textSecondary)
                }

                Spacer(minLength: CFSpacing.medium)

                ProgressView()
                    .tint(CFColors.primaryOrange)
            }
        }
    }

    private var titleSkeleton: some View {
        CFCardContainer {
            VStack(alignment: .leading, spacing: CFSpacing.medium) {
                skeletonLine(widthRatio: 0.2, height: 13, color: CFColors.orangeHighlight.opacity(0.32))
                skeletonLine(widthRatio: 0.82, height: 28)
                skeletonLine(widthRatio: 0.58, height: 28)
            }
        }
    }

    private var sourceSkeleton: some View {
        CFCardContainer {
            HStack(spacing: CFSpacing.medium) {
                RoundedRectangle(cornerRadius: CFCornerRadius.large, style: .continuous)
                    .fill(skeletonFill)
                    .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: CFSpacing.small) {
                    skeletonLine(widthRatio: 0.48, height: 20)
                    skeletonLine(widthRatio: 0.38, height: 15)
                    skeletonLine(widthRatio: 0.32, height: 13, color: CFColors.fieldSurface.opacity(0.72))
                }

                Spacer(minLength: CFSpacing.medium)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CFColors.placeholderText.opacity(0.5))
            }
        }
    }

    private var detailSkeleton: some View {
        CFCardContainer {
            VStack(alignment: .leading, spacing: CFSpacing.large) {
                HStack(spacing: CFSpacing.medium) {
                    RoundedRectangle(cornerRadius: CFCornerRadius.medium, style: .continuous)
                        .fill(CFColors.success.opacity(0.72))
                        .frame(width: 40, height: 40)

                    skeletonLine(widthRatio: 0.46, height: 20)
                }

                VStack(alignment: .leading, spacing: CFSpacing.medium) {
                    skeletonPill(widthRatio: 0.66)
                    skeletonPill(widthRatio: 0.5)
                    skeletonPill(widthRatio: 0.58)
                    skeletonPill(widthRatio: 0.74)
                }
            }
        }
    }

    private func skeletonPill(widthRatio: CGFloat) -> some View {
        GeometryReader { proxy in
            HStack(spacing: CFSpacing.medium) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(CFColors.primaryOrange.opacity(0.8))

                skeletonLine(widthRatio: 1, height: 17)
            }
            .padding(.horizontal, CFSpacing.medium)
            .frame(width: max(proxy.size.width * widthRatio, 132), height: 43, alignment: .leading)
            .background(CFColors.secondarySurface.opacity(0.64))
            .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.large, style: .continuous))
        }
        .frame(height: 43)
    }

    private func skeletonLine(
        widthRatio: CGFloat,
        height: CGFloat,
        color: Color? = nil
    ) -> some View {
        GeometryReader { proxy in
            RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                .fill(color ?? skeletonFill)
                .frame(width: max(proxy.size.width * widthRatio, height), height: height)
                .opacity(pulse ? 0.78 : 0.48)
                .animation(
                    enablesMotionEffects ? .easeInOut(duration: 0.95).repeatForever(autoreverses: true) : nil,
                    value: pulse
                )
        }
        .frame(height: height)
    }

    private var skeletonFill: Color {
        CFColors.fieldSurface.opacity(0.88)
    }
}
