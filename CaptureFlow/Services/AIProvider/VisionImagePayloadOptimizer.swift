import Foundation
import UIKit

struct VisionImagePayloadOptimizer: Sendable {
    struct Configuration: Sendable {
        var maxPixelDimension: CGFloat
        var compressionQuality: CGFloat

        init(
            maxPixelDimension: CGFloat = 1600,
            compressionQuality: CGFloat = 0.84
        ) {
            self.maxPixelDimension = maxPixelDimension
            self.compressionQuality = compressionQuality
        }
    }

    private let configuration: Configuration

    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    func optimizedImageData(from imageData: Data) -> Data {
        guard let image = UIImage(data: imageData),
              image.size.width > 0,
              image.size.height > 0
        else {
            return imageData
        }

        let imageForEncoding = resizedImageIfNeeded(image)
        return imageForEncoding.jpegData(compressionQuality: configuration.compressionQuality) ?? imageData
    }

    private func resizedImageIfNeeded(_ image: UIImage) -> UIImage {
        let scale = min(
            1,
            configuration.maxPixelDimension / max(image.size.width, image.size.height)
        )

        guard scale < 1 else {
            return image
        }

        let targetSize = CGSize(
            width: floor(image.size.width * scale),
            height: floor(image.size.height * scale)
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            UIColor.white.setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: targetSize)).fill()
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
