# CaptureFlow Agent Instructions

This file gives Codex and other coding agents the project context needed to work safely in this repository.

## Project Summary

CaptureFlow is a SwiftUI iOS local prototype for a Vision-to-Action app. The current goal is to validate user flow and product feel, not to ship production integrations.

The prototype flow is:

1. Home
2. `New Card`
3. Add image from camera or photo import
4. Select card type
5. Analyze with local mock services
6. Generate an editable `ActionCard`
7. Save to local Inbox, create mock Reminder/Calendar actions, copy Markdown, archive, or delete

## Current Scope

The current version must remain local and mock-first.

Do not add these unless the user explicitly asks:

- RevenueCat
- Firebase
- OpenAI API
- Real backend
- Real Cloud Vision
- Real account login
- Real cloud sync
- Real production credits

## Architecture

Use the existing lightweight MVVM and protocol-oriented structure.

```text
CaptureFlow/
  App/              AppContainer and AppRoute
  DesignSystem/     Reusable UI components and visual tokens
  Domain/           Pure Codable models and Markdown export
  Services/         Protocols, service models, mock implementations
  Repositories/     Local card repository boundary
  Features/         SwiftUI workflows and view models
```

## Module Boundaries

`Domain`
: Pure model layer. Keep it free of SwiftUI, UIKit, EventKit, network SDKs, Firebase, RevenueCat, and OpenAI.

`Services`
: Service protocols and implementations. Add real implementations here later, behind existing protocols.

`Repositories`
: Persistence boundary. `InMemoryCardRepository` is the prototype implementation. Future SwiftData work should conform to `CardRepository`.

`Features`
: User-facing SwiftUI screens and view models. Feature code should depend on protocols, not concrete service implementations.

`DesignSystem`
: Shared UI primitives. Prefer extending existing design system components over creating one-off styles.

`App`
: Dependency wiring and navigation routes.

## Existing Replacement Points

Keep these protocols as the main integration boundaries:

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

## UI Rules

Maintain the current design direction:

- Dark mode first
- Black and orange palette
- Rounded card-based UI
- Clean premium utility feel
- Cards should fill available width
- Action buttons in the same visual group should have consistent height
- Image previews must have stable dimensions and must not resize the whole screen based on source image size

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

- Keep changes scoped to the user's request.
- Preserve the local mock flow as the default path.
- Do not introduce real service SDKs without explicit instruction.
- Keep domain models Codable and testable.
- Use Swift Concurrency for async service/repository work.
- Avoid broad refactors unless needed to complete the task safely.
- Do not rewrite unrelated files.
- Do not commit ignored local files such as `buildServer.json` or Xcode `xcuserdata`.

## Build Command

Use this command to verify app builds:

```sh
xcodebuild -project CaptureFlow.xcodeproj -scheme CaptureFlow -destination 'generic/platform=iOS Simulator' build
```

The current project can emit an AppIntents metadata warning because AppIntents are not used. That warning is not a blocker.

## Git Notes

The remote is expected to be:

```text
git@github.com:MikeChen1109/CaptureFlow.git
```

Before committing, check:

```sh
git status --short
git diff --stat
```

Commit only intentional source/docs/project changes.
