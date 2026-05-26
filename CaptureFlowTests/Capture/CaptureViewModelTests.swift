import Testing
import UIKit
@testable import CaptureFlow

@MainActor
struct CaptureViewModelTests {
    @Test func cameraImageDoesNotCreateLocalSourceImageCopy() throws {
        let viewModel = CaptureViewModel()

        viewModel.loadCameraImage(try makeImage())
        let request = try viewModel.makeAnalysisRequest()

        #expect(request.imageData != nil)
        #expect(request.sourceImage?.source == .camera)
        #expect(request.sourceImage?.localPath == nil)
        #expect(request.sourceImage?.assetLocalIdentifier == nil)
    }

    private func makeImage() throws -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32))
        return renderer.image { context in
            UIColor.white.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        }
    }
}
