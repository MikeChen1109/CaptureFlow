# Architecture

CaptureFlow uses a single Swift module with feature-oriented folders and protocol-based service boundaries. Captured images are copied into app support storage and generated insights are persisted on device, while AI-backed analysis and generation can send user content to the configured provider. External systems are reached through narrow service protocols.

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
    Storage/

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
    Inbox/
    NewCardFlow/
    Settings/

  Resources/
    Assets.xcassets/
    LaunchScreen.storyboard

  Services/
    AIProvider/
    CardGeneration/
    EventKit/
    FoundationModels/
    Mock/
    Models/
    OpenAI/
    Providers/
    Protocols/
```

## Responsibilities

`App`
: App entry point, root navigation, dependency composition, and route definitions.

`Data`
: Persistence boundaries and storage implementations. `CardRepository` is the abstraction used by feature view models. `SwiftDataCardRepository` is the production local implementation, `InMemoryCardRepository` is retained for previews/tests/fallbacks, and `SourceImageFileStore` stores imported source images under app support storage.

`DesignSystem`
: Reusable SwiftUI components, view modifiers, typography, spacing, color, and radius tokens.

`Domain`
: Pure app models and export logic. Domain files should stay independent from SwiftUI, UIKit, EventKit, provider SDKs, and network SDKs.
Persisted card metadata such as custom fields belongs here; UI affordances for those models should live in feature-level extensions.

`Features`
: Workflow-specific SwiftUI screens and view models. Feature code can compose domain models, repositories, services, and design system primitives, but should continue to depend on protocols for AI, persistence, reminders, and calendars.

`Resources`
: Asset catalogs, launch screen resources, and future local resource files.

`Services`
: External capability boundaries and implementations for analysis, generation, provider-backed LLM requests, reminders, and calendars.

## Runtime Flow

1. `ContentView` owns the root `NavigationStack`, home state, inbox state, settings navigation, and the full-screen new-card flow.
2. `NewCardFlowView` starts at `CapturePreviewView`, where a user captures an image or imports one from Photos.
3. `CaptureViewModel` keeps the selected image data and saves a JPEG copy through `SourceImageFileStore` when possible.
4. `CardResultGenerationView` runs the pipeline: `AnalysisViewModel` calls `VisionAnalyzing`, then `CardGenerating` produces a `GeneratedInsightCard` and an `ActionCard`.
5. `CardResultViewModel` lets the user review generated sections, add custom fields, copy Markdown, create supported external actions, and save the result.
6. Saved cards become `SavedInsightCard` records through `CardRepository`.
7. Home shows the newest active insights; Inbox loads all active, expired, and archived insights with search and filtering.
8. Detail can update custom fields, copy Markdown, create supported actions, archive, or delete a saved insight.

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
- `OpenAIResponsesCardGenerator` for external LLM insight generation
- `AppleFoundationCardGenerator` on iOS 26+ when Foundation Models is available
- `MockVisionAnalyzer` for tests and local fallback use
- `MockCardGenerator` fallback
- `SwiftDataCardRepository` for saved insights
- `SourceImageFileStore` for copied source images
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

## AI and Prompts

Image analysis providers live behind `VisionAnalysisProviding`, and text generation providers live behind `LLMProviding`. `OpenAIVisionAnalysisProvider` is the first image-analysis provider implementation. `OpenAIResponsesLLMProvider` is the first generation provider implementation and owns HTTP, timeout, retry, response decoding, and provider error normalization.

`AppContainer.local()` reads `AIProviderConfiguration.current()` once and uses it to compose both LLM-backed paths:

- Vision model: `ProviderVisionAnalyzer` implements `VisionAnalyzing` and turns provider DTOs into `VisionUnderstandingContext`.
- Generation model: `CardGeneratorRouter` implements `CardGenerating` and chooses the configured external LLM provider or Foundation Models for insight-card generation.
- Vision prompt provider: `VisionAnalysisPromptProviding` owns reusable image-analysis instructions and the request-specific prompt. The default implementation is `DefaultVisionAnalysisPromptProvider`; integrators can inject a custom provider at composition time.
- Generation prompt provider: `CardGenerationPromptProviding` owns reusable generation instructions and context formatting. The default implementation is `DefaultCardGenerationPromptProvider`; integrators can inject a custom provider at composition time.

Prompts are code-owned by default. New prompt behavior should be added by replacing `VisionAnalysisPromptProviding` or `CardGenerationPromptProviding`, not by adding prompt text to feature views.

## Card Generation

Feature code continues to depend on `CardGenerating`. `AppContainer` injects a `CardGeneratorRouter` that resolves the active generator at request time:

1. External LLM, using the configured provider through `LLMProviding`. The default implementation is OpenAI with `gpt-4.1`.
2. Foundation Model, using Apple Foundation Models only when iOS 26+ Foundation Models are available, which requires Apple Intelligence to be enabled.
3. If Foundation Models are selected but unavailable, routing falls back to the external LLM provider.

`OpenAIResponsesCardGenerator` and `AppleFoundationCardGenerator` both produce a `GeneratedInsightCard`. `GeneratedActionCardFactory` maps the generated insight plus `VisionUnderstandingContext` into an `ActionCard` adapter:

- `ReminderCard` can create Reminders.
- `CalendarCard` can create Calendar events.
- `ShoppingCard` and `JobCard` can create Reminders.
- `NoteCard` is saved/exported but has no direct EventKit action.

Generated and saved cards can include custom fields. Custom fields are persisted on `SavedInsightCard`, appended to Markdown exports, and can enrich reminder/calendar requests when dates, times, locations, or notes are supplied by the user.

## Configuration

API keys are not collected in app UI. OpenAI-backed vision analysis and external LLM generation share the same local configuration:

```text
CAPTUREFLOW_AI_PROVIDER=openai
CAPTUREFLOW_OPENAI_API_KEY=your-api-key
```

These values can be supplied as Xcode scheme environment variables or in `CaptureFlow/Resources/LocalSecrets.plist`, which is ignored by git. Provider name and model names are composition-time configuration through `LLMProviderConfiguration`, not end-user settings. The default OpenAI vision model is `gpt-4.1-mini`, and the default OpenAI generation model is `gpt-4.1`. User defaults only store the generation route selection.

OpenAI vision analysis uses the local `DefaultVisionAnalysisPromptProvider` prompt by default. Custom prompt behavior should reuse or replace `VisionAnalysisPromptProviding` so the app keeps the same DTO contract.

Vision provider requests send image data. Generation provider requests are built from `VisionUnderstandingContext` and generation preferences.

`AIProviderConfiguration` currently supports:

- `CAPTUREFLOW_AI_PROVIDER=openai` to enable OpenAI-backed vision analysis.
- `CAPTUREFLOW_OPENAI_API_KEY` or `OPENAI_API_KEY` for credentials.
- `CAPTUREFLOW_OPENAI_VISION_MODEL` for the OpenAI vision model override.
- `CAPTUREFLOW_OPENAI_RESPONSES_URL` for endpoint override in local/provider testing.

## Persistence

`SavedInsightCard` is the persisted aggregate. It stores the generated insight, optional action-card adapter, custom fields, source-image metadata, status, and external action IDs. `SwiftDataSavedInsightCard` stores searchable/sortable scalar fields alongside an externally stored encoded card payload, then decodes back into the domain model when fetched.

Repository rules:

- `save(_:)` marks a generated card as `.saved`.
- `update(_:)` refreshes `updatedAt`.
- `archiveCard(id:)` marks a card `.archived`; normal fetches exclude archived cards unless requested.
- `deleteCard(id:)` removes the SwiftData record.
- `reset()` deletes all saved insight records. It does not currently delete copied source-image files.

Source images are not stored in SwiftData. `SourceImageFileStore` writes JPEG files under `Application Support/CaptureFlow/SourceImages` and stores relative paths such as `SourceImages/<uuid>.jpg` on `CardSourceImage`.

## External Actions

EventKit integration lives behind `ReminderCreating` and `CalendarCreating`.

- `EventKitReminderCreator` creates reminders from `ReminderCreationRequest`.
- `EventKitCalendarCreator` creates events from `CalendarCreationRequest`.
- Created external IDs are written back to `SavedInsightCard` and the nested action-card adapter.
- Detail and result screens prevent duplicate external action creation when an external ID is already present.

## Minimum Platform

The app, unit tests, and UI tests target iOS 18.0. iOS 26-only UI such as Liquid Glass is accessed through shared compatibility modifiers in `DesignSystem/Modifiers`, so feature views do not call `glassEffect` directly.
