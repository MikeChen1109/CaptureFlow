import SwiftUI

struct CardDetailView: View {
    @StateObject private var viewModel: CardDetailViewModel
    let onClose: () -> Void

    init(
        viewModel: CardDetailViewModel,
        onClose: @escaping () -> Void = {}
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
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
        .navigationTitle("Card Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await viewModel.load()
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
            markdownSection(card)
            actions
        } else {
            CFEmptyStateView(
                title: "Card unavailable",
                message: viewModel.errorMessage ?? "This card may have been deleted.",
                systemImage: "exclamationmark.triangle"
            )
        }
    }

    private func header(_ card: ActionCard) -> some View {
        CFCardContainer {
            VStack(alignment: .leading, spacing: CFSpacing.large) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: CFSpacing.small) {
                        Text(card.type.displayName)
                            .font(CFTypography.caption)
                            .foregroundStyle(CFColors.orangeHighlight)

                        Text(card.title)
                            .font(CFTypography.title)
                            .foregroundStyle(CFColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(statusText(card))
                            .font(CFTypography.callout)
                            .foregroundStyle(CFColors.textSecondary)
                    }

                    Spacer()

                    CFConfidenceBadge(level: card.confidence, score: card.confidenceScore)
                }
            }
        }
    }

    private func sourceSection(_ card: ActionCard) -> some View {
        CFCardContainer {
            HStack(spacing: CFSpacing.medium) {
                Image(systemName: sourceImageName(card))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(CFColors.background)
                    .frame(width: 52, height: 52)
                    .background(CFColors.primaryOrange)
                    .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.large, style: .continuous))

                VStack(alignment: .leading, spacing: CFSpacing.xSmall) {
                    Text("Source Image")
                        .font(CFTypography.headline)
                        .foregroundStyle(CFColors.textPrimary)

                    Text(sourceText(card))
                        .font(CFTypography.callout)
                        .foregroundStyle(CFColors.textSecondary)
                        .lineLimit(2)
                }

                Spacer()
            }
        }
    }

    private func markdownSection(_ card: ActionCard) -> some View {
        CFCardContainer {
            VStack(alignment: .leading, spacing: CFSpacing.medium) {
                Text("Markdown")
                    .font(CFTypography.headline)
                    .foregroundStyle(CFColors.textPrimary)

                Text(card.markdown)
                    .font(CFTypography.callout)
                    .foregroundStyle(CFColors.textSecondary)
                    .textSelection(.enabled)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: CFSpacing.medium) {
            CFSecondaryButton(
                viewModel.didCopyMarkdown ? "Markdown Copied" : "Copy Markdown",
                systemImage: viewModel.didCopyMarkdown ? "checkmark" : "doc.on.doc.fill"
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
                        if await viewModel.archive() {
                            onClose()
                        }
                    }
                }

                CFSecondaryButton(
                    viewModel.isDeleting ? "Deleting..." : "Delete",
                    systemImage: "trash.fill",
                    isDisabled: viewModel.isArchiving || viewModel.isDeleting
                ) {
                    Task {
                        if await viewModel.delete() {
                            onClose()
                        }
                    }
                }
            }

            if let actionMessage = viewModel.actionMessage {
                Text(actionMessage)
                    .font(CFTypography.callout)
                    .foregroundStyle(CFColors.orangeHighlight)
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

    private func statusText(_ card: ActionCard) -> String {
        "Status: \(card.status.rawValue.capitalized)"
    }

    private func sourceText(_ card: ActionCard) -> String {
        guard let sourceImage = card.sourceImage else {
            return "Mock source"
        }

        let source = sourceImage.source.rawValue
            .replacingOccurrences(of: "photoLibrary", with: "photo library")
        return sourceImage.originalFilename ?? source.capitalized
    }

    private func sourceImageName(_ card: ActionCard) -> String {
        switch card.sourceImage?.source {
        case .camera:
            "camera.fill"
        case .photoLibrary:
            "photo.on.rectangle"
        case .shareExtension:
            "square.and.arrow.down.fill"
        case .mock, .none:
            "sparkles"
        }
    }
}
