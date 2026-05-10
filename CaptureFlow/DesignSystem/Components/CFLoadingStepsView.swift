import SwiftUI

struct CFLoadingStepsView: View {
    let steps: [String]
    let currentStepIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: CFSpacing.medium) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(spacing: CFSpacing.medium) {
                    indicator(for: index)

                    Text(step)
                        .font(CFTypography.callout)
                        .foregroundStyle(index <= currentStepIndex ? CFColors.textPrimary : CFColors.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)
                }
            }
        }
    }

    @ViewBuilder
    private func indicator(for index: Int) -> some View {
        if index < currentStepIndex {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(CFColors.background)
                .frame(width: 22, height: 22)
                .background(CFColors.orangeHighlight)
                .clipShape(Circle())
        } else if index == currentStepIndex {
            ProgressView()
                .tint(CFColors.primaryOrange)
                .frame(width: 22, height: 22)
        } else {
            Circle()
                .stroke(CFColors.border, lineWidth: 1)
                .frame(width: 22, height: 22)
        }
    }
}
