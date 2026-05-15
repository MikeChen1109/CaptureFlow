# CaptureFlow

CaptureFlow is a local-first iOS prototype for turning captured visual context into useful insight cards. The app lets a user import or capture an image, analyze it, generate an editable insight, save it to a local inbox, and turn supported insights into Reminders or Calendar events.

This repository focuses on validating product flow, data boundaries, and UI feel. It does not connect to a real backend, Firebase, RevenueCat, OpenAI API, or account system.

## Current Prototype Scope

- SwiftUI app with a dark mode first interface
- Image capture from camera or Photos
- Local source-image persistence for newly imported images, with preview support in detail
- Mock image understanding through `MockVisionAnalyzer`
- Insight generation through `CardGenerating`, preferring Apple Foundation Models on iOS 26+ and falling back to mock generation
- Saved insight inbox backed by `SavedInsightCard`
- Detail view with generated sections, source image context, Markdown export, archive, and delete
- EventKit-backed Reminder and Calendar creation
- External action state tracking through stored Reminder and Calendar identifiers
- Local in-memory repository boundary for future persistent storage
- Mock credits and prototype settings/reset screen

## Main Flow

1. Home shows recent saved insights and mock credits.
2. User taps `New Insight`.
3. User captures an image or imports one from Photos.
4. CaptureFlow stores a local source-image copy when possible.
5. User taps Analyze.
6. `MockVisionAnalyzer` creates a `VisionUnderstandingContext`.
7. `CardGenerating` streams generated insight sections and an action-capable card adapter.
8. User reviews and edits generated content.
9. User saves the result as a `SavedInsightCard`.
10. Home and Insight Detail can create supported Reminder or Calendar actions.
11. Created external action IDs are written back to the saved insight so UI state can stay in sync.

## Data Model

`SavedInsightCard` is the main saved inbox model. It combines:

- `CardMetadata`: identity, timestamps, confidence, source image, and lifecycle status
- `GeneratedInsightCard`: title, summary, sections, usefulness, and confidence
- `ActionCard?`: optional adapter for Reminder, Calendar, Note, Shopping, or Job workflows
- `reminderExternalID`: EventKit reminder identifier after creation
- `calendarExternalID`: EventKit event identifier after creation

The repository currently stores `SavedInsightCard` values in memory. A future SwiftData or file-backed repository should persist the full `SavedInsightCard`, including `sourceImage.localPath`, `reminderExternalID`, and `calendarExternalID`.

## Source Images

`CardSourceImage` records where an insight came from:

- `source`: camera, Photos library, share extension, or mock
- `localPath`: local image copy used for detail previews when available
- `originalFilename`: reserved for user-friendly file names
- `capturedAt`: source timestamp

The app should not show raw Photos picker identifiers in user-facing UI. Detail presents source images as friendly context such as `From Photos Library` or `Saved in CaptureFlow`, and shows a thumbnail/preview when `localPath` is available.

## Architecture

CaptureFlow uses lightweight MVVM with protocol-oriented service boundaries. The current implementations are local-first and prototype-safe while keeping replacement points for future production integrations.

```text
CaptureFlow/
  App/
    AppContainer.swift
    AppRoute.swift

  DesignSystem/
    Components/
    Tokens/

  Domain/
    Cards/
    Export/
    Types/

  Services/
    Protocols/
    Models/
    Mock/
    FoundationModels/
    EventKit/

  Repositories/

  Features/
    Home/
    NewCardFlow/
    Capture/
    Analysis/
    CardResult/
    CardDetail/
    Settings/
```

## Module Responsibilities

`App`
: Dependency composition and navigation route definitions. `AppContainer.prototype()` wires local services, the in-memory repository, EventKit action services, and the default card generator.

`DesignSystem`
: Shared colors, typography, spacing, card containers, buttons, badges, empty states, loading steps, and image preview components.

`Domain`
: Pure app models and export logic. Domain models should remain Codable and should not import SwiftUI, UIKit, EventKit, Firebase, RevenueCat, OpenAI SDKs, or network SDKs.

`Services`
: Protocols and service implementations for vision analysis, card generation, credits, Reminder creation, and Calendar creation.

`Repositories`
: Persistence boundary for saved insights. `InMemoryCardRepository` is the current prototype implementation; SwiftData or a file-backed store can replace it behind `CardRepository`.

`Features`
: SwiftUI screens and view models grouped by workflow.

## Core Protocols

- `VisionAnalyzing`
- `CardGenerating`
- `CardRepository`
- `ReminderCreating`
- `CalendarCreating`
- `CreditProviding`

Current implementations:

- `MockVisionAnalyzer`
- `AppleFoundationCardGenerator` on iOS 26+ when `FoundationModels` is available
- `MockCardGenerator` fallback
- `InMemoryCardRepository`
- `EventKitReminderCreator`
- `EventKitCalendarCreator`
- `MockCreditProvider`

Future replacements:

- `MockVisionAnalyzer` -> cloud or on-device vision analyzer
- `InMemoryCardRepository` -> SwiftData or file-backed persistent repository
- `MockCreditProvider` -> RevenueCat plus backend credit provider
- Prototype source-image storage -> managed media storage with cleanup

## UI Direction

- Dark mode first
- Insight-first language: use `Insight`, `New Insight`, and `Recent Insights`
- Home cards should prioritize title, summary, date, and lightweight action state
- Avoid showing internal type/status tags unless they help the user act
- Detail should show readable source context, generated sections, and available external actions
- External action states should be clear and persistent, for example `Reminder saved` or `Reminder Created`
- Premium AI utility feel, focused workflow, not a traditional todo app

Key colors:

- Background: `#09090B`
- Surface: `#151518`
- Elevated Surface: `#1D1D22`
- Secondary Surface: `#24242B`
- Primary Orange: `#FF7A1A`
- Orange Highlight: `#FF9F45`
- Text Primary: `#F5F5F7`
- Text Secondary: `#B8B8C4`
- Border: `#34343D`

## Build

```sh
xcodebuild -project CaptureFlow.xcodeproj -scheme CaptureFlow -destination 'generic/platform=iOS Simulator' build
```

The current build may show AppIntents metadata warnings if Xcode scans intent metadata. Those warnings are unrelated to prototype behavior.

## Current Non-Goals

Do not add these in the local prototype unless the scope explicitly changes:

- Firebase
- OpenAI API
- Real backend
- Real account login
- Real cloud sync
- Real credit accounting
- RevenueCat purchase flow

## Development Notes

- Keep feature code small and workflow-oriented.
- Prefer existing design system components before adding new UI primitives.
- Keep domain models pure and Codable.
- Add real services behind existing protocols instead of changing feature screens directly.
- Preserve the local mock-safe fallback path even when adding more capable generators.
- When adding persistent storage, persist the entire `SavedInsightCard` and keep external action IDs and source-image paths intact.
