import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel

    init(viewModel: SettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CFSpacing.xLarge) {
                header
                prototypeNotice
                creditsSection
                resetSection
            }
            .padding(CFSpacing.large)
        }
        .background(CFColors.background.ignoresSafeArea())
        .navigationTitle("Prototype Info")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await viewModel.load()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: CFSpacing.small) {
            Text("CaptureFlow")
                .font(CFTypography.title)
                .foregroundStyle(CFColors.textPrimary)

            Text("Local prototype mode")
                .font(CFTypography.callout)
                .foregroundStyle(CFColors.textSecondary)
        }
    }

    private var prototypeNotice: some View {
        CFCardContainer {
            VStack(alignment: .leading, spacing: CFSpacing.medium) {
                labelRow("Vision analysis", value: "MockVisionAnalyzer")
                labelRow("Insight generation", value: "Apple Foundation Models")
                labelRow("Credits", value: "MockCreditProvider")
                labelRow("Storage", value: "In-memory repository")
                labelRow("External actions", value: "Mock Reminder / Calendar")
            }
        }
    }

    private var creditsSection: some View {
        CFCardContainer {
            VStack(alignment: .leading, spacing: CFSpacing.medium) {
                Text("Mock Credits")
                    .font(CFTypography.headline)
                    .foregroundStyle(CFColors.textPrimary)

                if viewModel.isLoading {
                    ProgressView()
                        .tint(CFColors.primaryOrange)
                } else if let creditBalance = viewModel.creditBalance {
                    Text("\(creditBalance.remaining) / \(creditBalance.limit) remaining")
                        .font(CFTypography.title)
                        .foregroundStyle(CFColors.orangeHighlight)
                } else {
                    Text("--")
                        .font(CFTypography.title)
                        .foregroundStyle(CFColors.textSecondary)
                }
            }
        }
    }

    private var resetSection: some View {
        VStack(spacing: CFSpacing.medium) {
            CFSecondaryButton(
                viewModel.isResetting ? "Resetting..." : "Reset Local Data",
                systemImage: "arrow.counterclockwise",
                isDisabled: viewModel.isResetting
            ) {
                Task {
                    await viewModel.resetPrototypeData()
                }
            }

            if let actionMessage = viewModel.actionMessage {
                Text(actionMessage)
                    .font(CFTypography.callout)
                    .foregroundStyle(CFColors.orangeHighlight)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(CFTypography.callout)
                    .foregroundStyle(CFColors.destructive)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func labelRow(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(CFTypography.callout)
                .foregroundStyle(CFColors.textSecondary)

            Spacer(minLength: CFSpacing.medium)

            Text(value)
                .font(CFTypography.callout.weight(.semibold))
                .foregroundStyle(CFColors.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }
}
