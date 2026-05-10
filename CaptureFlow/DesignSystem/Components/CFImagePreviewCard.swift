import SwiftUI

struct CFImagePreviewCard: View {
    var image: Image?
    var title: String
    var subtitle: String?
    var height: CGFloat

    init(
        image: Image? = nil,
        title: String = "Image Preview",
        subtitle: String? = nil,
        height: CGFloat = 320
    ) {
        self.image = image
        self.title = title
        self.subtitle = subtitle
        self.height = height
    }

    var body: some View {
        CFCardContainer(padding: 0) {
            ZStack(alignment: .bottomLeading) {
                preview

                LinearGradient(
                    colors: [.clear, CFColors.background.opacity(0.78)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: CFSpacing.xSmall) {
                    Text(title)
                        .font(CFTypography.headline)
                        .foregroundStyle(CFColors.textPrimary)
                        .lineLimit(1)

                    if let subtitle {
                        Text(subtitle)
                            .font(CFTypography.callout)
                            .foregroundStyle(CFColors.textSecondary)
                            .lineLimit(2)
                    }
                }
                .padding(CFSpacing.large)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipped()
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var preview: some View {
        GeometryReader { proxy in
            if let image {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            } else {
                ZStack {
                    CFColors.secondarySurface

                    Image(systemName: "photo")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(CFColors.textSecondary)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }
}
