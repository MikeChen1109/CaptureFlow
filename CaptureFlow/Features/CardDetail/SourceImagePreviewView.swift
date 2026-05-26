import Photos
import SwiftUI
import UIKit

struct SourceImageSectionView: View {
    let card: SavedInsightCard
    @Binding var previewSourceImage: CardSourceImage?

    private var presentation: SourceImagePresentation {
        SourceImagePresentation(card: card)
    }

    var body: some View {
        CFCardContainer {
            HStack(spacing: CFSpacing.medium) {
                SourceImageThumbnail(
                    presentation: presentation,
                    sourceImage: card.sourceImage
                )

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

                if presentation.canOpenPreview {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CFColors.placeholderText)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: openPreview)
        }
    }

    private func openPreview() {
        guard presentation.canOpenPreview else { return }
        previewSourceImage = card.sourceImage
    }
}

private struct SourceImageThumbnail: View {
    let presentation: SourceImagePresentation
    let sourceImage: CardSourceImage?
    @State private var thumbnailImage: UIImage?

    @ViewBuilder
    var body: some View {
        Group {
            if let thumbnailImage {
                thumbnail(thumbnailImage)
            } else {
                Image(systemName: presentation.systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(CFColors.background)
                    .frame(width: 56, height: 56)
                    .background(CFColors.primaryOrange)
                    .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.large, style: .continuous))
            }
        }
        .task(id: photoAssetIdentifier) {
            await loadThumbnail()
        }
    }

    private func thumbnail(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.large, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: CFCornerRadius.large, style: .continuous)
                    .stroke(CFColors.border, lineWidth: 1)
            }
    }

    private var photoAssetIdentifier: String? {
        guard sourceImage?.source == .photoLibrary else {
            return nil
        }

        return sourceImage?.assetLocalIdentifier
    }

    private func loadThumbnail() async {
        thumbnailImage = nil

        guard let photoAssetIdentifier else {
            return
        }

        thumbnailImage = try? await PhotoLibrarySourceImageLoader.thumbnail(
            assetLocalIdentifier: photoAssetIdentifier,
            targetSize: CGSize(
                width: 56 * UIScreen.main.scale,
                height: 56 * UIScreen.main.scale
            )
        )
    }
}

@MainActor
private struct SourceImagePresentation {
    let title: String
    let subtitle: String
    let hint: String
    let systemImage: String
    let canOpenPreview: Bool

    init(card: SavedInsightCard) {
        let sourceImage = card.sourceImage
        canOpenPreview = sourceImage?.canAttemptPreview == true

        switch sourceImage?.source {
        case .photoLibrary:
            title = "Source Image"
            subtitle = "From Photos Library"
            hint = canOpenPreview ? "Tap to preview original" : "Original preview unavailable"
            systemImage = "photo.on.rectangle"
        case .camera:
            title = "Original Screenshot"
            subtitle = "Camera Capture"
            hint = canOpenPreview ? "Tap to view" : "Original preview unavailable"
            systemImage = "camera.fill"
        case .shareExtension:
            title = "Source Image"
            subtitle = "Imported from Share Sheet"
            hint = canOpenPreview ? "Tap to preview original" : "Original preview unavailable"
            systemImage = "square.and.arrow.down.fill"
        case .mock, .none:
            title = "Source Image"
            subtitle = "Sample insight"
            hint = "Original preview unavailable"
            systemImage = "sparkles"
        }
    }
}

private struct SourceImagePreview: Identifiable {
    let id: UUID
    let image: UIImage
    let title: String

    init(id: UUID, image: UIImage, title: String) {
        self.id = id
        self.image = image
        self.title = title
    }

}

struct SourceImagePreviewView: View {
    let sourceImage: CardSourceImage

    @Environment(\.dismiss) private var dismiss
    @State private var preview: SourceImagePreview?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if let preview {
                ZoomableSourceImageView(image: preview.image)
                    .ignoresSafeArea()
            } else if isLoading {
                ProgressView()
                    .tint(CFColors.primaryOrange)
            } else {
                CFEmptyStateView(
                    title: "Original preview unavailable",
                    message: errorMessage ?? "The source image may have been deleted from Photos.",
                    systemImage: "photo.badge.exclamationmark"
                )
                .padding(CFSpacing.large)
            }

            VStack {
                HStack {
                    Spacer()

                    Button("Done") {
                        dismiss()
                    }
                    .font(CFTypography.callout.weight(.semibold))
                    .foregroundStyle(CFColors.orangeHighlight)
                    .padding(.horizontal, CFSpacing.medium)
                    .padding(.vertical, CFSpacing.small)
                    .background(.ultraThinMaterial, in: Capsule())
                }
                .padding(.horizontal, CFSpacing.large)
                .padding(.top, CFSpacing.small)

                Spacer()
            }
        }
        .statusBarHidden()
        .task {
            await loadPreview()
        }
    }

    private func loadPreview() async {
        isLoading = true
        errorMessage = nil

        if let localPath = sourceImage.resolvedLocalPreviewPath {
            do {
                let image = try await LocalSourceImageLoader.image(localPath: localPath)
                preview = SourceImagePreview(id: sourceImage.id, image: image, title: sourceImage.previewTitle)
            } catch {
                errorMessage = "The saved source image file is no longer available."
            }
            isLoading = false
            return
        }

        guard sourceImage.source == .photoLibrary,
              let assetLocalIdentifier = sourceImage.assetLocalIdentifier
        else {
            errorMessage = "The saved source image file is no longer available."
            isLoading = false
            return
        }

        do {
            let image = try await PhotoLibrarySourceImageLoader.image(assetLocalIdentifier: assetLocalIdentifier)
            preview = SourceImagePreview(id: sourceImage.id, image: image, title: sourceImage.previewTitle)
        } catch {
            errorMessage = "The source photo is no longer available in Photos."
        }

        isLoading = false
    }
}

private enum LocalSourceImageLoader {
    static func image(localPath: String) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let image = UIImage(contentsOfFile: localPath) else {
                    continuation.resume(throwing: ServiceError.noImageProvided)
                    return
                }

                continuation.resume(returning: image)
            }
        }
    }
}

private struct ZoomableSourceImageView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .black
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 6
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false

        let imageView = context.coordinator.imageView
        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.frameLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.frameLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.toggleZoom(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.scrollView = scrollView
        context.coordinator.imageView.image = image
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        let imageView = UIImageView()
        weak var scrollView: UIScrollView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        @objc func toggleZoom(_ recognizer: UITapGestureRecognizer) {
            guard let scrollView else { return }

            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
                return
            }

            let point = recognizer.location(in: imageView)
            let zoomScale = min(scrollView.maximumZoomScale, 3)
            let size = CGSize(
                width: scrollView.bounds.width / zoomScale,
                height: scrollView.bounds.height / zoomScale
            )
            let origin = CGPoint(
                x: point.x - size.width / 2,
                y: point.y - size.height / 2
            )
            scrollView.zoom(to: CGRect(origin: origin, size: size), animated: true)
        }
    }
}

private enum PhotoLibrarySourceImageLoader {
    static func thumbnail(
        assetLocalIdentifier: String,
        targetSize: CGSize
    ) async throws -> UIImage {
        guard hasReadAccess else {
            throw ServiceError.permissionDenied
        }

        let asset = try asset(assetLocalIdentifier: assetLocalIdentifier)

        return try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .fastFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = false
            options.isSynchronous = false

            var didResume = false

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                guard !didResume else { return }

                if let image {
                    didResume = true
                    continuation.resume(returning: image)
                    return
                }

                let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool == true
                let isCancelled = info?[PHImageCancelledKey] as? Bool == true
                let error = info?[PHImageErrorKey] as? Error

                if isCancelled || error != nil || !isDegraded {
                    didResume = true
                    continuation.resume(throwing: error ?? ServiceError.noImageProvided)
                }
            }
        }
    }

    static func image(assetLocalIdentifier: String) async throws -> UIImage {
        try await ensureReadAccess()
        let asset = try asset(assetLocalIdentifier: assetLocalIdentifier)

        return try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            PHImageManager.default().requestImageDataAndOrientation(
                for: asset,
                options: options
            ) { data, _, _, _ in
                guard let data,
                      let image = UIImage(data: data)
                else {
                    continuation.resume(throwing: ServiceError.noImageProvided)
                    return
                }

                continuation.resume(returning: image)
            }
        }
    }

    private static func ensureReadAccess() async throws {
        if hasReadAccess {
            return
        }

        if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .notDetermined {
            let requestedStatus = await requestReadAccess()
            guard requestedStatus == .authorized || requestedStatus == .limited else {
                throw ServiceError.permissionDenied
            }
            return
        }

        throw ServiceError.permissionDenied
    }

    private static var hasReadAccess: Bool {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized, .limited:
            true
        case .notDetermined, .denied, .restricted:
            false
        @unknown default:
            false
        }
    }

    private static func requestReadAccess() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }

    private static func asset(assetLocalIdentifier: String) throws -> PHAsset {
        let result = PHAsset.fetchAssets(
            withLocalIdentifiers: [assetLocalIdentifier],
            options: nil
        )

        guard let asset = result.firstObject else {
            throw ServiceError.noImageProvided
        }

        return asset
    }
}

private extension CardSourceImage {
    var canAttemptPreview: Bool {
        if resolvedLocalPreviewPath != nil {
            return true
        }

        return source == .photoLibrary && assetLocalIdentifier != nil
    }

    var resolvedLocalPreviewPath: String? {
        guard let storedPath = localPath?.trimmingCharacters(in: .whitespacesAndNewlines),
              !storedPath.isEmpty
        else {
            return nil
        }

        return try? SourceImageFileStore().resolvedPath(for: storedPath)
    }

    var previewTitle: String {
        switch source {
        case .camera:
            "Original Screenshot"
        case .photoLibrary, .shareExtension:
            "Source Image"
        case .mock:
            "Sample Source"
        }
    }
}
