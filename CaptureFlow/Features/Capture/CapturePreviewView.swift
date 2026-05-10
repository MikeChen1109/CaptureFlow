import PhotosUI
import SwiftUI
import UIKit

struct CapturePreviewView: View {
    @StateObject private var viewModel = CaptureViewModel()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isShowingCamera = false
    let onAnalyze: (VisionAnalysisRequest) -> Void

    init(onAnalyze: @escaping (VisionAnalysisRequest) -> Void = { _ in }) {
        self.onAnalyze = onAnalyze
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CFSpacing.xLarge) {
                header
                imagePreview
                imageActions
                cardTypeSection
                analyzeSection
            }
            .padding(.horizontal, CFSpacing.large)
            .padding(.vertical, CFSpacing.xLarge)
        }
        .background(CFColors.background.ignoresSafeArea())
        .navigationTitle("Add Image")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onChange(of: selectedPhotoItem) { _, newValue in
            Task {
                await viewModel.loadPhoto(from: newValue)
            }
        }
        .sheet(isPresented: $isShowingCamera) {
            CameraImagePicker { image in
                viewModel.loadCameraImage(image)
                isShowingCamera = false
            } onCancel: {
                isShowingCamera = false
            }
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: CFSpacing.small) {
            Text("Add Image")
                .font(CFTypography.title)
                .foregroundStyle(CFColors.textPrimary)

            Text("Prototype mode: analysis is simulated locally.")
                .font(CFTypography.callout)
                .foregroundStyle(CFColors.textSecondary)
        }
    }

    private var imagePreview: some View {
        CFImagePreviewCard(
            image: viewModel.selectedImage,
            title: viewModel.selectedImage == nil ? "No image selected" : "Ready to analyze",
            subtitle: viewModel.selectedImage == nil ? "Import an image to create an action card." : "Choose a card type, then analyze."
        )
    }

    private var imageActions: some View {
        let isLoadingImage = viewModel.isLoadingImage
        let hasSelectedImage = viewModel.selectedImage != nil
        let isCameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)

        return VStack(spacing: CFSpacing.medium) {
            HStack(spacing: CFSpacing.medium) {
                CFSecondaryButton(
                    "Take Photo",
                    systemImage: "camera.fill",
                    isDisabled: !isCameraAvailable
                ) {
                    isShowingCamera = true
                }

                PhotosPicker(
                    selection: $selectedPhotoItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    HStack(spacing: CFSpacing.small) {
                        if isLoadingImage {
                            ProgressView()
                                .tint(CFColors.textPrimary)
                        } else {
                            Image(systemName: "photo.on.rectangle")
                                .imageScale(.medium)
                        }

                        Text(hasSelectedImage ? "Replace" : "Import Image")
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }
                    .font(CFTypography.callout.weight(.semibold))
                    .foregroundStyle(CFColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(CFColors.secondarySurface)
                    .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.pill, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: CFCornerRadius.pill, style: .continuous)
                            .stroke(CFColors.border, lineWidth: 1)
                    }
                }
                .disabled(isLoadingImage)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(CFTypography.callout)
                    .foregroundStyle(CFColors.destructive)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if !isCameraAvailable {
                Text("Camera is unavailable on this device. Import an image to continue.")
                    .font(CFTypography.caption)
                    .foregroundStyle(CFColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var cardTypeSection: some View {
        VStack(alignment: .leading, spacing: CFSpacing.medium) {
            Text("Card Type")
                .font(CFTypography.headline)
                .foregroundStyle(CFColors.textPrimary)

            CardTypePickerView(selectedCardType: $viewModel.selectedCardType)
        }
    }

    private var analyzeSection: some View {
        CFPrimaryButton(
            "Analyze",
            systemImage: "wand.and.sparkles",
            isDisabled: !viewModel.canAnalyze
        ) {
            do {
                onAnalyze(try viewModel.makeAnalysisRequest())
            } catch {
                viewModel.errorMessage = "Select an image before analyzing."
            }
        }
    }
}
