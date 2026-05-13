# CaptureFlow Agent Instructions

## Project Summary

CaptureFlow is a SwiftUI iOS local prototype for a Vision-to-Action app.

The core flow is:

1. Home
2. New Card
3. Add image from camera or photo import
4. Select card type
5. Analyze with local mock vision service
6. Generate editable ActionCard with on-device Foundation Models when available
7. Fall back to mock generation when Foundation Models is unavailable
8. Review, edit, save, create mock Reminder/Calendar actions, copy Markdown, archive, or delete

The current goal is fast prototype validation and product feel, not production integrations.

## Hard Scope Boundaries

Do not add these unless explicitly requested:

- RevenueCat
- Firebase
- OpenAI API
- Real backend
- Real Cloud Vision
- Real login/account system
- Real cloud sync
- Real production credits
- Real payment or subscription flow

Keep the local mock fallback path working.

## Architecture

Use the existing lightweight MVVM and protocol-oriented structure.

```text
CaptureFlow/
  App/              Dependency wiring and routes
  DesignSystem/     Shared UI components and visual tokens
  Domain/           Pure Codable models and Markdown export
  Services/         Protocols, mock services, FoundationModels generator
  Repositories/     Local card repository boundary
  Features/         SwiftUI workflows and view models
```

## Module Boundaries

- `Domain`: pure model layer. No SwiftUI, UIKit, EventKit, network SDKs, Firebase, RevenueCat, OpenAI, backend clients, or cloud dependencies.
- `Services`: service protocols and implementations. Foundation Models integration belongs here and must stay behind availability guards.
- `Repositories`: persistence boundary. Future SwiftData work should conform to `CardRepository`.
- `Features`: SwiftUI screens and view models. Depend on protocols, not concrete services.
- `DesignSystem`: shared colors, spacing, typography, containers, buttons, badges, loading UI, and image preview behavior.
- `App`: dependency wiring and navigation.

## Main Protocol Boundaries

Keep these as primary replacement points:

- `VisionAnalyzing`
- `CardGenerating`
- `CardRepository`
- `ReminderCreating`
- `CalendarCreating`
- `CreditProviding`

Current implementations:

- `MockVisionAnalyzer`
- `AppleFoundationCardGenerator`
- `MockCardGenerator`
- `InMemoryCardRepository`
- `MockReminderCreator`
- `MockCalendarCreator`
- `MockCreditProvider`

## Foundation Models Rules

- Keep `#if canImport(FoundationModels)`.
- Keep iOS availability guards.
- Use mock fallback when Foundation Models is unavailable.
- Do not remove or break the local fallback path.
- Prefer streaming APIs when the UI needs progressive generation.

## Generation UX Rules

The Card Result generation experience should feel like real progressive generation, similar to Apple's Foundation Models itinerary demo.

Do not implement the real generation path by waiting for a full `GeneratedCardContent` and then using `Task.sleep`, timers, or fake staged reveal.

Correct direction:

```text
CardGenerating
  -> AsyncThrowingStream<CardGenerationEvent, Error>
  -> CardResultGenerationView
  -> CardResultViewModel.applyPartialContent(...)
  -> GeneratedSectionState
  -> SwiftUI section cards
```

Avoid:

```text
generate full GeneratedCardContent
then replay sections with sleep-based reveal
```

Mock fallback may simulate streaming, but it should use the same event pipeline as the real Foundation Models path.

## Card Result Flow Rules

The result UI should appear while generation is running.

Expected progressive order:

1. Summary
2. Plan / Checklist
3. Recommended Actions
4. Draft Output
5. Key Details
6. Missing Info
7. Personal Note
8. Final action buttons only after completion

Do not split the experience into a summary-only generation screen followed by a final screen that fake-reveals completed content.

## UI Rules

Maintain the current design direction:

- Dark mode first
- Black and orange palette
- Rounded card-based UI
- Clean premium utility feel
- Cards fill available width
- Stable image preview dimensions
- Consistent button heights in the same visual group

Use existing components first:

- `CFCardContainer`
- `CFPrimaryButton`
- `CFSecondaryButton`
- `CFPillButton`
- `CFConfidenceBadge`
- `CFImagePreviewCard`
- `CFEmptyStateView`
- `CFLoadingStepsView`

## Development Rules

- Keep changes scoped to the request.
- Do not rewrite unrelated files.
- Do not globally reformat the project.
- Use Swift Concurrency for async work.
- Keep domain models Codable and testable.
- Preserve `Sendable` where already used.
- Avoid broad refactors unless required to complete the task safely.
- Do not commit ignored local files such as `buildServer.json` or Xcode `xcuserdata`.

## Debugging Rules

Before changing generation flow, inspect:

- `CardResultGenerationView`
- `CardResultViewModel`
- `AppleFoundationCardGenerator`
- `GeneratedSectionViews`
- `CardGenerating` protocol and related service models
- `MockCardGenerator`

For progressive generation bugs, check whether:

1. UI waits for `.completed` before showing most sections.
2. Only title/summary is streamed.
3. `GeneratedCardContent.fallback(from:)` replaces model-generated content.
4. `Task.sleep` reveal logic drives the real generation path.
5. Foundation Models partial output is mapped into section state.

## Build Command

```sh
xcodebuild -project CaptureFlow.xcodeproj -scheme CaptureFlow -destination 'generic/platform=iOS Simulator' build
```

An AppIntents metadata warning is expected and not a blocker unless AppIntents are introduced.
