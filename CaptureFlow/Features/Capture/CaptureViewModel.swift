import Combine
import Foundation
import PhotosUI
import SwiftUI
import UIKit

@MainActor
final class CaptureViewModel: ObservableObject {
    @Published private(set) var selectedImage: Image?
    @Published private(set) var selectedImageData: Data?
    @Published private(set) var sourceImage: CardSourceImage?
    @Published private(set) var isLoadingImage = false
    @Published var errorMessage: String?

    private let sourceImageFileStore = try? SourceImageFileStore()

    var canAnalyze: Bool {
        selectedImageData != nil
    }

    func makeAnalysisRequest() throws -> VisionAnalysisRequest {
        guard let selectedImageData else {
            throw ServiceError.noImageProvided
        }

        return VisionAnalysisRequest(
            imageData: selectedImageData,
            sourceImage: sourceImage,
            selectedCardType: .auto
        )
    }

    func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else {
            return
        }

        isLoadingImage = true
        errorMessage = nil

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else {
                throw ServiceError.noImageProvided
            }
            let persistedData = uiImage.jpegData(compressionQuality: 0.86) ?? data
            let localPath = try persistSourceImageData(persistedData)

            selectedImageData = data
            selectedImage = Image(uiImage: uiImage)
            sourceImage = CardSourceImage(
                source: .photoLibrary,
                localPath: localPath,
                assetLocalIdentifier: item.itemIdentifier
            )
        } catch {
            errorMessage = "Unable to import this image."
        }

        isLoadingImage = false
    }

    func loadCameraImage(_ uiImage: UIImage) {
        guard let data = uiImage.jpegData(compressionQuality: 0.86) else {
            errorMessage = "Unable to read this photo."
            return
        }

        selectedImageData = data
        selectedImage = Image(uiImage: uiImage)
        sourceImage = CardSourceImage(
            source: .camera,
            localPath: try? persistSourceImageData(data)
        )
        errorMessage = nil
    }

    private func persistSourceImageData(_ data: Data) throws -> String {
        guard let sourceImageFileStore else {
            throw ServiceError.unavailable("Unable to prepare source image storage.")
        }

        return try sourceImageFileStore.saveImageData(data)
    }
}
