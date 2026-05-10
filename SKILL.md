# CaptureFlow Agent Skill

Use this prompt/context when continuing development on CaptureFlow.

## Project Identity

You are working on CaptureFlow, a SwiftUI iOS app prototype for a Vision-to-Action workflow. The product goal is to validate whether users can smoothly turn a photo or imported image into an editable action card, then save or export it.

CaptureFlow is currently a local prototype. Do not connect real backend services unless explicitly asked.

## Product Rules

Users should be able to:

- Start from Home with `New Card`
- Add an image from camera or photo import
- Choose a card type: Auto, Reminder, Calendar, Note, Shopping, Job
- Analyze with local mock services
- Review and edit the generated card
- Save to local Inbox
- Create mock Reminder or Calendar actions
- Copy Markdown
- Open saved cards from Inbox
- Archive or delete saved cards
- Reset prototype data from Settings

## Hard Scope Boundaries

Do not add these without explicit approval:

- RevenueCat
- Firebase
- OpenAI API
- Real backend
- Real cloud vision
- Real login/account system
- Real cloud sync
- Real production credit system

Keep the mock/local flow working even if future real implementations are added.

## Architecture Expectations

Use the existing lightweight MVVM and protocol-oriented structure:

```text
CaptureFlow/
  App/              Dependency container and app routes
  DesignSystem/     Shared visual language and reusable UI primitives
  Domain/           Pure Codable models and Markdown export
  Services/         Protocols, service models, mock implementations
  Repositories/     CardRepository and local persistence implementations
  Features/         User-facing workflows and view models
```

Respect these boundaries:

- `Domain` must stay pure: no SwiftUI, UIKit, EventKit, network SDKs, Firebase, RevenueCat, or OpenAI.
- `Features` can use SwiftUI and view models, but should depend on protocols rather than concrete services.
- `Services/Protocols` define replacement points for real integrations.
- `AppContainer` wires concrete implementations.
- `DesignSystem` owns shared colors, spacing, typography, card containers, buttons, badges, loading UI, and image preview behavior.

## Important Protocols

Existing service boundaries:

- `VisionAnalyzing`
- `CardGenerating`
- `CardRepository`
- `ReminderCreating`
- `CalendarCreating`
- `CreditProviding`

Current prototype implementations:

- `MockVisionAnalyzer`
- `MockCardGenerator`
- `InMemoryCardRepository`
- `MockReminderCreator`
- `MockCalendarCreator`
- `MockCreditProvider`

Future implementation targets:

- `CloudVisionAnalyzer`
- `AppleFoundationCardGenerator`
- `SwiftDataCardRepository`
- EventKit-backed reminder/calendar creators
- RevenueCat plus backend-backed credit provider

## Design Rules

Maintain the current product feel:

- Dark mode first
- Black/orange palette
- Card-based UI
- Large rounded surfaces
- Clean, focused utility experience
- Use color and hierarchy for primary/secondary actions, not inconsistent button sizes
- Cards should generally fill available width
- Image previews must use stable dimensions and must not resize the whole screen based on source image size

Use existing design system components whenever possible:

- `CFCardContainer`
- `CFPrimaryButton`
- `CFSecondaryButton`
- `CFPillButton`
- `CFConfidenceBadge`
- `CFImagePreviewCard`
- `CFEmptyStateView`
- `CFLoadingStepsView`

## Implementation Style

- Keep changes scoped to the requested feature or bug.
- Prefer small, testable view models.
- Keep async work behind services/repositories.
- Use Swift Concurrency.
- Preserve Codable and Sendable where already used.
- Avoid adding broad abstractions until there is real duplication or a clear replacement point.
- Do not rewrite unrelated files or reformat the project globally.

## Build Command

Use this command to verify changes:

```sh
xcodebuild -project CaptureFlow.xcodeproj -scheme CaptureFlow -destination 'generic/platform=iOS Simulator' build
```

An AppIntents metadata warning is currently expected and not relevant unless AppIntents are introduced.

## Suggested Next Work

Good next steps for future agents:

- Add focused unit tests for domain Markdown export and mock card generation.
- Replace in-memory repository with `SwiftDataCardRepository` behind `CardRepository`.
- Add real EventKit implementations behind `ReminderCreating` and `CalendarCreating`.
- Improve card editing UX with type-specific form components.
- Add Share Extension later, after core app flow is stable.

## Agent Prompt

When continuing development, act as a senior iOS architect and product-minded mobile engineer. Prioritize fast prototype validation, clean replacement points, and UI consistency. Read the existing modules before editing. Keep real service integrations out of scope unless the user explicitly asks for them. Preserve the local mock path as the default development flow.
