import SwiftUI
import UIKit

struct CardDetailView: View {
    @StateObject private var viewModel: CardDetailViewModel
    @State private var previewSourceImage: SourceImagePreview?
    let onCardUpdated: (SavedInsightCard) -> Void
    let onCardDeleted: () -> Void
    let onClose: () -> Void

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
            VStack(alignment: .leading, spacing: CFSpacing.xLarge) {
                content
            }
            .padding(CFSpacing.large)
        }
        .background(CFColors.background.ignoresSafeArea())
        .navigationTitle("Insight Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await viewModel.load()
        }
        .sheet(item: $previewSourceImage) { preview in
            SourceImagePreviewView(preview: preview)
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            CFCardContainer {
                HStack(spacing: CFSpacing.medium) {
                    ProgressView()
                        .tint(CFColors.primaryOrange)

                    Text("Loading card")
                        .font(CFTypography.callout)
                        .foregroundStyle(CFColors.textSecondary)
                }
            }
        } else if let card = viewModel.card {
            header(card)
            sourceSection(card)
            insightSections(card)
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
        let presentation = SourceImagePresentation(card: card)

        return CFCardContainer {
            HStack(spacing: CFSpacing.medium) {
                sourceThumbnail(presentation)

                VStack(alignment: .leading, spacing: CFSpacing.xSmall) {
                    Text(presentation.title)
                        .font(CFTypography.headline)
                        .foregroundStyle(CFColors.textPrimary)

                    Text(presentation.subtitle)
                        .font(CFTypography.callout)
                        .foregroundStyle(CFColors.textSecondary)
                        .lineLimit(2)

                    Text(presentation.hint)
                        .font(CFTypography.caption)
                        .foregroundStyle(CFColors.placeholderText)
                        .lineLimit(1)
                }

                Spacer()

                if presentation.preview != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CFColors.placeholderText)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                previewSourceImage = presentation.preview
            }
        }
    }

    @ViewBuilder
    private func sourceThumbnail(_ presentation: SourceImagePresentation) -> some View {
        if let preview = presentation.preview {
            Image(uiImage: preview.image)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.large, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: CFCornerRadius.large, style: .continuous)
                        .stroke(CFColors.border, lineWidth: 1)
                }
        } else {
            Image(systemName: presentation.systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(CFColors.background)
                .frame(width: 56, height: 56)
                .background(CFColors.primaryOrange)
                .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.large, style: .continuous))
        }
    }

    private func insightSections(_ card: SavedInsightCard) -> some View {
        VStack(alignment: .leading, spacing: CFSpacing.large) {
            ForEach(card.insight.sections.sorted { $0.priority < $1.priority }) { section in
                InsightSectionView(section: section)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: CFSpacing.medium) {
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

            CFSecondaryButton(
                viewModel.didCopyMarkdown ? "Markdown Copied" : "Copy Markdown",
                systemImage: viewModel.didCopyMarkdown ? "checkmark" : "doc.on.doc.fill",
                tone: viewModel.didCopyMarkdown ? .success : .normal
            ) {
                viewModel.copyMarkdown()
            }

            HStack(spacing: CFSpacing.medium) {
                CFSecondaryButton(
                    viewModel.isArchiving ? "Archiving..." : "Archive",
                    systemImage: "archivebox.fill",
                    isDisabled: viewModel.isArchiving || viewModel.isDeleting
                ) {
                    Task {
                        if let updatedCard = await viewModel.archive() {
                            onCardUpdated(updatedCard)
                            onClose()
                        }
                    }
                }

                CFSecondaryButton(
                    viewModel.isDeleting ? "Deleting..." : "Delete",
                    systemImage: "trash.fill",
                    tone: .destructive,
                    isDisabled: viewModel.isArchiving || viewModel.isDeleting
                ) {
                    Task {
                        if await viewModel.delete() {
                            onCardDeleted()
                            onClose()
                        }
                    }
                }
            }

            if let actionMessage = viewModel.actionMessage {
                Text(actionMessage)
                    .font(CFTypography.callout)
                    .foregroundStyle(CFColors.success)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(CFTypography.callout)
                    .foregroundStyle(CFColors.destructive)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

}

@MainActor
private struct SourceImagePresentation {
    let title: String
    let subtitle: String
    let hint: String
    let systemImage: String
    let preview: SourceImagePreview?

    init(card: SavedInsightCard) {
        let sourceImage = card.sourceImage
        preview = sourceImage.flatMap(SourceImagePreview.init(sourceImage:))

        switch sourceImage?.source {
        case .photoLibrary:
            title = "Source Image"
            subtitle = "From Photos Library"
            hint = preview == nil ? "Original preview unavailable" : "Tap to preview original"
            systemImage = "photo.on.rectangle"
        case .camera:
            title = "Original Screenshot"
            subtitle = "Saved in CaptureFlow"
            hint = preview == nil ? "Original preview unavailable" : "Tap to view"
            systemImage = "camera.fill"
        case .shareExtension:
            title = "Source Image"
            subtitle = "Imported from Share Sheet"
            hint = preview == nil ? "Original preview unavailable" : "Tap to preview original"
            systemImage = "square.and.arrow.down.fill"
        case .mock, .none:
            title = "Source Image"
            subtitle = "Prototype sample"
            hint = "Original preview unavailable"
            systemImage = "sparkles"
        }
    }
}

private struct SourceImagePreview: Identifiable {
    let id: UUID
    let image: UIImage
    let title: String

    init?(sourceImage: CardSourceImage) {
        guard let localPath = sourceImage.localPath,
              let image = UIImage(contentsOfFile: localPath)
        else {
            return nil
        }

        self.id = sourceImage.id
        self.image = image
        self.title = switch sourceImage.source {
        case .camera:
            "Original Screenshot"
        case .photoLibrary, .shareExtension:
            "Source Image"
        case .mock:
            "Prototype Source"
        }
    }
}

private struct SourceImagePreviewView: View {
    let preview: SourceImagePreview
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                CFColors.background.ignoresSafeArea()

                Image(uiImage: preview.image)
                    .resizable()
                    .scaledToFit()
                    .padding(CFSpacing.large)
            }
            .navigationTitle(preview.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(CFColors.orangeHighlight)
                }
            }
        }
        .presentationDetents([.large])
    }
}
