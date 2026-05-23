<p align="center">
  <img src="CaptureFlow/Resources/Assets.xcassets/AppIcon.appiconset/1024.png" alt="CaptureFlow app icon" width="128">
</p>

# CaptureFlow

CaptureFlow is a local-first open-source iOS tool for turning captured visual context into useful insight cards. A user can capture or import an image, analyze it, generate an editable insight, save it locally, and turn supported insights into Reminders or Calendar events.

## Current Scope

- SwiftUI app with a dark-mode-first interface
- Image capture from camera or Photos
- Local source-image persistence for newly imported images
- Vision understanding through `VisionAnalyzing`, with OpenAI as the default provider-backed implementation
- Insight generation through `CardGenerating`
- Analysis/generation routing: external LLM by default, or Apple Foundation Models on iOS 26+ with Apple Intelligence enabled when selected
- Saved insight inbox backed by `SavedInsightCard`
- Detail view with generated sections, source image context, Markdown export, archive, and delete
- EventKit-backed Reminder and Calendar creation
- Settings page for generation provider selection and local data reset

## Repository Layout

```text
CaptureFlow/
  App/              App entry point, root navigation, dependency composition
  Data/             Repository protocols and persistence implementations
  DesignSystem/     Shared SwiftUI components, modifiers, and tokens
  Domain/           Pure app models, types, and export logic
  Features/         Workflow-specific screens and view models
  Resources/        Assets and launch resources
  Services/         Service protocols, models, mocks, EventKit, and generation

CaptureFlowTests/   Unit tests
CaptureFlowUITests/ UI tests
docs/               Architecture notes and roadmap
```

For more detail, see [Architecture](docs/ARCHITECTURE.md).

## Main Flow

1. Home shows recent saved insights.
2. The user starts a new insight.
3. The user captures an image or imports one from Photos.
4. CaptureFlow stores a local source-image copy when possible.
5. `VisionAnalyzing` produces visual context.
6. `CardGenerating` streams generated insight sections and an action-capable card adapter.
7. The user reviews and edits generated content.
8. The user saves the result as a `SavedInsightCard`.
9. Detail can create supported Reminder or Calendar actions.
10. Created external action IDs are written back to the saved insight.

## Service Boundaries

- `VisionAnalyzing`
- `VisionAnalysisProviding`
- `CardGenerating`
- `LLMProviding`
- `CardRepository`
- `ReminderCreating`
- `CalendarCreating`

LLM strategy:

1. `VisionAnalysisProviding` is the provider extension point for image analysis.
2. `LLMProviding` is the provider extension point for text generation.
3. Vision uses `ProviderVisionAnalyzer` through `VisionAnalyzing`.
4. Generation uses `CardGeneratorRouter` through `CardGenerating`.
5. Generation defaults to the configured external LLM provider, with OpenAI and `gpt-4.1-mini` as the default configuration.
6. Settings can switch generation to Apple Foundation Models only when iOS 26+ Foundation Models are available, which requires Apple Intelligence to be enabled.
7. Generation prompts live behind `CardGenerationPromptProviding` so integrators can inject custom instructions and context formatting without changing generator implementations.

API keys are not entered in the app UI. Integrators inject a key source through `LLMProviderCredentialProviding` when composing `AppContainer`. `LLMProviderConfiguration` controls provider display name plus default vision and generation model names.

## Requirements

- Xcode 26.3 or newer
- iOS 18.0 minimum deployment target
- iOS 18 simulator runtime or newer

## Build

```sh
xcodebuild -project CaptureFlow.xcodeproj -scheme CaptureFlow -destination 'generic/platform=iOS Simulator' IPHONEOS_DEPLOYMENT_TARGET=18.0 build
```

Run tests:

```sh
xcodebuild test -project CaptureFlow.xcodeproj -scheme CaptureFlow -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max,OS=18.6'
```

If your simulator name differs, replace the destination with an installed simulator.

## Open Source

- Contributions: [CONTRIBUTING.md](CONTRIBUTING.md)
- Code of conduct: [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- Security policy: [SECURITY.md](SECURITY.md)
- Roadmap: [docs/ROADMAP.md](docs/ROADMAP.md)
- License: [MIT](LICENSE)
