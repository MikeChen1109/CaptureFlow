# Architecture

CaptureFlow uses a single Swift module with feature-oriented folders and protocol-based service boundaries. The app is intentionally local-first and keeps external integrations behind small protocols.

## Layout

```text
CaptureFlow/
  App/
    CaptureFlowApp.swift
    ContentView.swift
    AppContainer.swift
    AppRoute.swift

  Data/
    Repositories/

  DesignSystem/
    Components/
    Modifiers/
    Tokens/

  Domain/
    Cards/
    Export/
    Types/

  Features/
    Analysis/
    Capture/
    CardDetail/
    CardResult/
    Home/
    NewCardFlow/
    Settings/

  Resources/
    Assets.xcassets/
    LaunchScreen.storyboard

  Services/
    CardGeneration/
    EventKit/
    FoundationModels/
    Mock/
    Models/
    Providers/
    Protocols/
```

## Responsibilities

`App`
: App entry point, root navigation, dependency composition, and route definitions.

`Data`
: Persistence boundaries and repository implementations. `CardRepository` is the abstraction used by feature view models. `InMemoryCardRepository` is the current local implementation.

`DesignSystem`
: Reusable SwiftUI components, view modifiers, typography, spacing, color, and radius tokens.

`Domain`
: Pure app models and export logic. Domain files should stay independent from SwiftUI, UIKit, EventKit, provider SDKs, and network SDKs.

`Features`
: Workflow-specific SwiftUI screens and view models. Feature code can compose domain models, repositories, services, and design system primitives.

`Resources`
: Asset catalogs, launch screen resources, and future local resource files.

`Services`
: External capability boundaries and implementations for analysis, generation, provider-backed LLM requests, reminders, and calendars.

## Core Protocols

- `VisionAnalyzing`
- `VisionAnalysisProviding`
- `CardGenerating`
- `LLMProviding`
- `CardRepository`
- `ReminderCreating`
- `CalendarCreating`

## Current Implementations

- `OpenAIResponsesLLMProvider`
- `ProviderVisionAnalyzer` and `OpenAIVisionAnalysisProvider` for the provider-backed Vision path
- `CardGeneratorRouter`
- `OpenAIResponsesCardGenerator` for the OpenAI analyze/generation path
- `AppleFoundationCardGenerator` on iOS 26+ when Foundation Models is available
- `MockVisionAnalyzer` for tests and local fallback use
- `MockCardGenerator` fallback
- `InMemoryCardRepository`
- `EventKitReminderCreator`
- `EventKitCalendarCreator`

## Dependency Direction

Feature view models depend on protocols instead of concrete integrations. `AppContainer.local()` wires the current local implementations together.

```text
Features -> Domain
Features -> Data repositories through protocols
Features -> Services through protocols
Services -> Domain and service models
Data -> Domain
DesignSystem -> SwiftUI only
```

Keep this direction intact when adding production implementations. New storage, external actions, or AI providers should be introduced behind an existing protocol or a small new protocol rather than being called directly from SwiftUI views.

## Provider-Based LLMs

Image analysis providers live behind `VisionAnalysisProviding`, and text generation providers live behind `LLMProviding`. `OpenAIVisionAnalysisProvider` is the first image-analysis provider implementation. `OpenAIResponsesLLMProvider` is the first generation provider implementation and owns HTTP, timeout, retry, response decoding, and provider error normalization.

`AppContainer.local()` reads `AIProviderConfiguration.current()` once and uses it to compose both LLM-backed paths:

- Vision model: `ProviderVisionAnalyzer` implements `VisionAnalyzing` and turns provider DTOs into `VisionUnderstandingContext`.
- Generation model: `CardGeneratorRouter` implements `CardGenerating` and chooses the configured external LLM provider or Foundation Models for insight-card generation.
- Vision prompt provider: `VisionAnalysisPromptProviding` owns reusable image-analysis instructions and the request-specific prompt. The default implementation is `DefaultVisionAnalysisPromptProvider`; integrators can inject a custom provider at composition time.
- Generation prompt provider: `CardGenerationPromptProviding` owns reusable generation instructions and context formatting. The default implementation is `DefaultCardGenerationPromptProvider`; integrators can inject a custom provider at composition time.

## Generation Routing

Feature code continues to depend on `CardGenerating`. `AppContainer` injects a `CardGeneratorRouter` that resolves the active generator at request time:

1. External LLM, using the configured provider through `LLMProviding`. The default implementation is OpenAI with `gpt-4.1-mini`.
2. Foundation Model, using Apple Foundation Models only when iOS 26+ Foundation Models are available, which requires Apple Intelligence to be enabled.
3. If Foundation Models are selected but unavailable, routing falls back to the external LLM provider.

API keys are not collected in app UI. OpenAI-backed vision analysis and external LLM generation share the same local configuration:

```text
CAPTUREFLOW_AI_PROVIDER=openai
CAPTUREFLOW_OPENAI_API_KEY=your-api-key
```

These values can be supplied as Xcode scheme environment variables or in `CaptureFlow/Resources/LocalSecrets.plist`, which is ignored by git. Provider name and model names are composition-time configuration through `LLMProviderConfiguration`, not end-user settings. User defaults only store the generation route selection.

OpenAI vision analysis defaults to the local `DefaultVisionAnalysisPromptProvider` prompt. Teams that still want an OpenAI-hosted prompt can set `CAPTUREFLOW_OPENAI_PROMPT_ID` and optionally `CAPTUREFLOW_OPENAI_PROMPT_VERSION`; custom providers should reuse or replace `VisionAnalysisPromptProviding` so the app keeps the same DTO contract.

Vision provider requests send image data. Generation provider requests are built from `VisionUnderstandingContext` and generation preferences.

## Minimum Platform

The app, unit tests, and UI tests target iOS 18.0. iOS 26-only UI such as Liquid Glass is accessed through shared compatibility modifiers in `DesignSystem/Modifiers`, so feature views do not call `glassEffect` directly.
