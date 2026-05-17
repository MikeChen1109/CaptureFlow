import SwiftUI

struct CFLoadingStepsView: View {
    let steps: [String]
    let currentStepIndex: Int
    var showsActiveSpinner: Bool

    init(
        steps: [String],
        currentStepIndex: Int,
        showsActiveSpinner: Bool = true
    ) {
        self.steps = steps
        self.currentStepIndex = currentStepIndex
        self.showsActiveSpinner = showsActiveSpinner
    }

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
            if showsActiveSpinner {
                ProgressView()
                    .tint(CFColors.primaryOrange)
                    .frame(width: 22, height: 22)
            } else {
                Circle()
                    .fill(CFColors.primaryOrange.opacity(0.22))
                    .frame(width: 22, height: 22)
                    .overlay {
                        Circle()
                            .fill(CFColors.orangeHighlight)
                            .frame(width: 8, height: 8)
                    }
            }
        } else {
            Circle()
                .stroke(CFColors.border, lineWidth: 1)
                .frame(width: 22, height: 22)
        }
    }
}
