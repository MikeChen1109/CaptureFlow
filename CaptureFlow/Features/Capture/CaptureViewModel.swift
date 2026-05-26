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
            selectedCardType: .unknown
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

            selectedImageData = data
            selectedImage = Image(uiImage: uiImage)
            sourceImage = CardSourceImage(
                source: .photoLibrary,
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
            source: .camera
        )
        errorMessage = nil
    }
}
