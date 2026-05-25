<p align="center">
  <img src="CaptureFlow/Resources/Assets.xcassets/AppIcon.appiconset/1024.png" alt="CaptureFlow app icon" width="128">
</p>

# CaptureFlow

## Summary

CaptureFlow is a local-first, open-source iOS app that turns screenshots and captured images into actionable AI insight cards. Instead of letting screenshots become forgotten camera-roll clutter, CaptureFlow analyzes the visual context, summarizes what matters, and helps the user turn useful information into follow-up actions.

The app can capture or import an image, understand the screenshot with an AI vision provider, generate an editable card, save it locally, export it as Markdown, and turn supported cards into Reminders or Calendar events. The current AI-backed provider implementation uses OpenAI for analysis and generation, with Apple Foundation Models available for generation on supported iOS 26+ devices.

The codebase is designed around clear service boundaries, so teams can keep the default provider implementation or bring their own LLM, prompt, storage, and action integrations.

## Quick Start

1. Clone the repository and open `CaptureFlow.xcodeproj` in Xcode.
2. Configure an OpenAI API key for AI-backed analysis and generation.
3. Build and run the `CaptureFlow` scheme on an iOS simulator or device.
4. Optional: switch generation between External LLM and Apple Foundation Models in Settings when Foundation Models are available.

### API Key Setup

API keys are not entered in the app UI. Configure OpenAI-backed analysis and generation with Xcode scheme environment variables:

```text
CAPTUREFLOW_AI_PROVIDER=openai
CAPTUREFLOW_OPENAI_API_KEY=your-api-key
```

`OPENAI_API_KEY` is also accepted as a fallback key name. These values can also be supplied in `CaptureFlow/Resources/LocalSecrets.plist`, which is ignored by git:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CAPTUREFLOW_AI_PROVIDER</key>
  <string>openai</string>
  <key>CAPTUREFLOW_OPENAI_API_KEY</key>
  <string>your-api-key</string>
</dict>
</plist>
```

### Implement Your Own LLM

CaptureFlow keeps provider-specific behavior behind protocols so you can swap providers without rewriting the app flow.

- Use `VisionAnalysisProviding` to implement image analysis.
- Use `LLMProviding` to implement text generation.
- Update `LLMProviderConfiguration` to define provider display name and default model names.
- Wire your implementation through `AppContainer.local()` so features continue to depend on `VisionAnalyzing` and `CardGenerating`.
- Keep prompt changes in code by replacing `VisionAnalysisPromptProviding` or `CardGenerationPromptProviding`.

For more detail, see [Architecture](docs/ARCHITECTURE.md).

### Build

```sh
xcodebuild -project CaptureFlow.xcodeproj -scheme CaptureFlow -destination 'generic/platform=iOS Simulator' IPHONEOS_DEPLOYMENT_TARGET=18.0 build
```

Run tests:

```sh
xcodebuild test -project CaptureFlow.xcodeproj -scheme CaptureFlow -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max,OS=18.6'
```

If your simulator name differs, replace the destination with an installed simulator.

## Requirements

- Xcode 26.3 or newer
- iOS 18.0 minimum deployment target
- iOS 18 simulator runtime or newer

## Open Source

- Contributions: [CONTRIBUTING.md](CONTRIBUTING.md)
- Code of conduct: [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- Security policy: [SECURITY.md](SECURITY.md)
- License: [MIT](LICENSE)
