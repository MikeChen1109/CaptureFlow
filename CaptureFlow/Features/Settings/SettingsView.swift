import SwiftUI

struct SettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: SettingsViewModel
    @State private var isPresentingResetConfirmation = false

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
        .onAppear {
            viewModel.refreshGenerationAvailability()
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            viewModel.refreshGenerationAvailability()
        }
        .onChange(of: viewModel.actionMessage) { _, newValue in
            guard newValue != nil else { return }

            Task {
                try? await Task.sleep(for: .seconds(2))
                await MainActor.run {
                    viewModel.clearActionMessage()
                }
            }
        }
        .alert("Delete local saved insights?", isPresented: $isPresentingResetConfirmation) {
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.resetSavedInsights()
                }
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes saved insight data stored locally on this device. This action cannot be undone.")
        }
    }

    private var generationSection: some View {
        CFCardContainer {
            VStack(alignment: .leading, spacing: CFSpacing.large) {
                sectionHeader("Card Analysis", systemImage: "sparkles")

                foundationModelToggle

                VStack(alignment: .leading, spacing: CFSpacing.small) {
                    Label(viewModel.activeGenerationModeTitle, systemImage: "checkmark.circle")
                        .font(CFTypography.caption.weight(.semibold))
                        .foregroundStyle(CFColors.success)

                    Text(generationDescription)
                        .font(CFTypography.caption)
                        .foregroundStyle(CFColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var foundationModelToggle: some View {
        HStack(alignment: .top, spacing: CFSpacing.medium) {
            VStack(alignment: .leading, spacing: CFSpacing.xSmall) {
                availabilityBadge

                Text("Apple Foundation Model")
                    .font(CFTypography.callout.weight(.semibold))
                    .foregroundStyle(CFColors.textPrimary)
                    .lineLimit(1)
            }

            Spacer(minLength: CFSpacing.small)

            Toggle(
                "Use Apple Foundation Models",
                isOn: Binding(
                    get: { viewModel.usesFoundationModels },
                    set: { viewModel.setUsesFoundationModels($0) }
                )
            )
            .labelsHidden()
            .tint(CFColors.orangeHighlight)
            .disabled(!viewModel.isFoundationModelOptionEnabled)
            .padding(.top, -2)
        }
        .padding(CFSpacing.medium)
        .background(CFColors.elevatedSurface.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CFCornerRadius.medium, style: .continuous)
                .stroke(CFColors.border, lineWidth: 1)
        }
        .opacity(viewModel.isFoundationModelOptionEnabled ? 1 : 0.62)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Apple Foundation Model")
        .accessibilityValue(viewModel.usesFoundationModels ? "On" : "Off")
    }

    private var availabilityBadge: some View {
        Label(viewModel.foundationModelStatusTitle, systemImage: viewModel.foundationModelStatusSystemImage)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(viewModel.isFoundationModelOptionEnabled ? CFColors.success : CFColors.placeholderText)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, CFSpacing.small)
            .padding(.vertical, CFSpacing.xSmall)
            .background(
                (viewModel.isFoundationModelOptionEnabled ? CFColors.success : CFColors.fieldBorder)
                    .opacity(0.14)
            )
            .clipShape(Capsule())
    }

    private var generationDescription: String {
        "Off by default, CaptureFlow uses the configured OpenAI model for card analysis. Turning on Foundation Models can reduce external LLM budget, but requires iOS 26 or later with Apple Intelligence enabled."
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
                        isPresentingResetConfirmation = true
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

    private func sectionHeader(_ title: String, systemImage: String? = nil) -> some View {
        HStack(spacing: CFSpacing.small) {
            if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.medium)
                    .foregroundStyle(CFColors.orangeHighlight)
            }

            Text(title)
                .font(CFTypography.headline)
                .foregroundStyle(CFColors.textPrimary)
        }
    }
}
