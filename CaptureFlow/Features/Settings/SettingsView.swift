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
                outputSection
                experienceSection
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

    private var header: some View {
        VStack(alignment: .leading, spacing: CFSpacing.small) {
            Text("Settings")
                .font(CFTypography.title)
                .foregroundStyle(CFColors.textPrimary)

            Text("Tune generated insights and app motion.")
                .font(CFTypography.callout)
                .foregroundStyle(CFColors.textSecondary)
        }
    }

    private var outputSection: some View {
        CFCardContainer {
            VStack(alignment: .leading, spacing: CFSpacing.large) {
                sectionHeader("Generated Content", systemImage: "text.badge.star")

                VStack(alignment: .leading, spacing: CFSpacing.medium) {
                    settingLabel("Detail")

                    Picker("Detail", selection: $viewModel.outputDetail) {
                        ForEach(InsightOutputDetail.allCases) { detail in
                            Text(detail.title).tag(detail)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: CFSpacing.medium) {
                    settingLabel("Tone")

                    Picker("Tone", selection: $viewModel.outputTone) {
                        ForEach(InsightOutputTone.allCases) { tone in
                            Text(tone.title).tag(tone)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }

    private var experienceSection: some View {
        CFCardContainer {
            VStack(alignment: .leading, spacing: CFSpacing.large) {
                sectionHeader("Experience", systemImage: "sparkles")

                Toggle(isOn: $viewModel.enablesMotionEffects) {
                    VStack(alignment: .leading, spacing: CFSpacing.xSmall) {
                        Text("Motion Effects")
                            .font(CFTypography.callout.weight(.semibold))
                            .foregroundStyle(CFColors.textPrimary)

                        Text("Loading and reveal animations")
                            .font(CFTypography.caption)
                            .foregroundStyle(CFColors.textSecondary)
                    }
                }
                .tint(CFColors.primaryOrange)
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
