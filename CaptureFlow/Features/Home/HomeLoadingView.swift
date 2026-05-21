import SwiftUI

struct HomeLoadingView: View {
    @State private var pulse = false
    @AppStorage(GenerationPreferences.Keys.enablesMotionEffects) private var enablesMotionEffects = true

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    CFColors.background,
                    CFColors.background,
                    CFColors.secondarySurface
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: CFSpacing.xLarge) {
                ZStack {
                    Circle()
                        .fill(CFColors.primaryOrange.opacity(0.18))
                        .frame(width: pulse ? 146 : 118, height: pulse ? 146 : 118)
                        .blur(radius: 8)

                    RoundedRectangle(cornerRadius: CFCornerRadius.xLarge, style: .continuous)
                        .fill(CFColors.surface)
                        .frame(width: 94, height: 94)
                        .overlay {
                            RoundedRectangle(cornerRadius: CFCornerRadius.xLarge, style: .continuous)
                                .stroke(CFColors.border, lineWidth: 1)
                        }

                    Image(systemName: "viewfinder.circle.fill")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(CFColors.orangeHighlight)
                }
                .animation(
                    enablesMotionEffects ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true) : nil,
                    value: pulse
                )

                VStack(spacing: CFSpacing.small) {
                    Text("Preparing Your Inbox")
                        .font(CFTypography.title)
                        .foregroundStyle(CFColors.textPrimary)

                    Text("Loading saved insights...")
                        .font(CFTypography.callout)
                        .foregroundStyle(CFColors.textSecondary)
                }

                ProgressView()
                    .tint(CFColors.primaryOrange)
            }
            .padding(.horizontal, CFSpacing.large)
        }
        .task {
            pulse = enablesMotionEffects
        }
    }
}
