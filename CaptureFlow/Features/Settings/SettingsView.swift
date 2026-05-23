import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel

    init(viewModel: SettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CFSpacing.xLarge) {
                generationSection
                dataSection
            }
            .padding(CFSpacing.large)
        }
        .captureFlowParticleBackground()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onChange(of: viewModel.actionMessage) { _, newValue in
            guard newValue != nil else { return }

            Task {
                try? await Task.sleep(for: .seconds(2))
                await MainActor.run {
                    viewModel.clearActionMessage()
                }
            }
        }
    }

    private var generationSection: some View {
        CFCardContainer {
            VStack(alignment: .leading, spacing: CFSpacing.large) {
                sectionHeader("Generation", systemImage: "cpu")

                VStack(alignment: .leading, spacing: CFSpacing.medium) {
                    settingLabel("Generation Provider")

                    Picker("Generation Provider", selection: $viewModel.generationModelSelection) {
                        ForEach(GenerationModelSelection.allCases) { model in
                            Text(model.title).tag(model)
                                .disabled(model == .foundationModels && !viewModel.isFoundationModelOptionEnabled)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(viewModel.generationModelSelection.detail)
                        .font(CFTypography.caption)
                        .foregroundStyle(CFColors.textSecondary)

                    if viewModel.generationModelSelection == .foundationModels {
                        Text(viewModel.foundationModelRequirementText)
                            .font(CFTypography.caption)
                            .foregroundStyle(
                                viewModel.isFoundationModelOptionEnabled ? CFColors.textSecondary : CFColors.orangeHighlight
                            )
                    }
                }

                VStack(alignment: .leading, spacing: CFSpacing.xSmall) {
                    Text(viewModel.activeGenerationModeTitle)
                        .font(CFTypography.callout.weight(.semibold))
                        .foregroundStyle(CFColors.textPrimary)

                    Text(viewModel.activeGenerationModeDetail)
                        .font(CFTypography.caption)
                        .foregroundStyle(CFColors.textSecondary)
                }
            }
        }
    }

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: CFSpacing.medium) {
            CFCardContainer {
                VStack(alignment: .leading, spacing: CFSpacing.large) {
                    sectionHeader("Data", systemImage: "tray.full")

                    CFSecondaryButton(
                        viewModel.isResetting ? "Resetting..." : "Reset Saved Insights",
                        systemImage: "arrow.counterclockwise",
                        tone: .destructive,
                        isDisabled: viewModel.isResetting
                    ) {
                        Task {
                            await viewModel.resetSavedInsights()
                        }
                    }
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

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: CFSpacing.small) {
            Image(systemName: systemImage)
                .imageScale(.medium)
                .foregroundStyle(CFColors.orangeHighlight)

            Text(title)
                .font(CFTypography.headline)
                .foregroundStyle(CFColors.textPrimary)
        }
    }

    private func settingLabel(_ title: String) -> some View {
        Text(title)
            .font(CFTypography.callout.weight(.semibold))
            .foregroundStyle(CFColors.textPrimary)
    }
}
