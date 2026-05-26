import Testing
import UIKit
@testable import CaptureFlow

@MainActor
struct VisionImagePayloadOptimizerTests {
    @Test func optimizerDownscalesImagesThatExceedMaximumDimension() throws {
        let imageData = try makeJPEGData(size: CGSize(width: 3000, height: 1200))
        let optimizer = VisionImagePayloadOptimizer(
            configuration: VisionImagePayloadOptimizer.Configuration(
                maxPixelDimension: 1200,
                compressionQuality: 0.82
            )
        )

        let optimizedData = optimizer.optimizedImageData(from: imageData)
        let optimizedImage = try #require(UIImage(data: optimizedData))

        #expect(max(optimizedImage.size.width, optimizedImage.size.height) <= 1200)
        #expect(optimizedImage.size.width == 1200)
        #expect(optimizedImage.size.height == 480)
    }

    @Test func optimizerKeepsSmallImageDimensions() throws {
        let imageData = try makeJPEGData(size: CGSize(width: 900, height: 600))
        let optimizer = VisionImagePayloadOptimizer(
            configuration: VisionImagePayloadOptimizer.Configuration(
                maxPixelDimension: 1200,
                compressionQuality: 0.82
            )
        )

        let optimizedData = optimizer.optimizedImageData(from: imageData)
        let optimizedImage = try #require(UIImage(data: optimizedData))

        #expect(optimizedImage.size == CGSize(width: 900, height: 600))
    }

    @Test func optimizerReturnsOriginalDataWhenImageCannotBeDecoded() {
        let invalidData = Data("not image data".utf8)
        let optimizer = VisionImagePayloadOptimizer()

        #expect(optimizer.optimizedImageData(from: invalidData) == invalidData)
    }

    @Test func providerAnalyzerSendsOptimizedImageDataToProvider() async throws {
        let provider = CapturingVisionAnalysisProvider()
        let analyzer = ProviderVisionAnalyzer(
            provider: provider,
            imagePayloadOptimizer: VisionImagePayloadOptimizer(
                configuration: VisionImagePayloadOptimizer.Configuration(
                    maxPixelDimension: 1000,
                    compressionQuality: 0.82
                )
            )
        )

        _ = try await analyzer.analyze(
            VisionAnalysisRequest(
                imageData: try makeJPEGData(size: CGSize(width: 2400, height: 1200)),
                selectedCardType: .unknown
            )
        )

        let capturedImageData = try #require(provider.capturedImageData)
        let capturedImage = try #require(UIImage(data: capturedImageData))
        #expect(capturedImage.size == CGSize(width: 1000, height: 500))
    }

    private final class CapturingVisionAnalysisProvider: VisionAnalysisProviding, @unchecked Sendable {
        let providerID = "test"
        private(set) var capturedImageData: Data?

        func analyzeImage(_ request: VisionProviderAnalysisRequest) async throws -> VisionAnalysisDTO {
            capturedImageData = request.imageData
            return VisionAnalysisDTO(
                resolvedCardType: .note,
                sceneTitle: "Optimized image",
                sceneSummary: "The provider received optimized image data.",
                confidenceScore: 0.9
            )
        }
    }

    private func makeJPEGData(size: CGSize) throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.cgContext.fill(CGRect(origin: .zero, size: size))
            UIColor.black.setStroke()
            let path = UIBezierPath()
            stride(from: 0, through: size.width, by: 48).forEach { x in
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: size.width - x, y: size.height))
            }
            path.lineWidth = 3
            path.stroke()
        }

        return try #require(image.jpegData(compressionQuality: 0.95))
    }
}
