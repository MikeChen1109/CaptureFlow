# CaptureFlow

CaptureFlow is a local-first iOS prototype for a Vision-to-Action workflow. The app lets a user add an image, simulate image understanding, generate an editable action card, and save or export the result.

This repository currently focuses on validating product flow and UI feel. It does not connect to a real backend, OpenAI, Firebase, RevenueCat, or a real credits system.

## Current Prototype Scope

- SwiftUI app with dark mode first UI
- Local mock analysis flow
- Photo import and camera capture entry points
- Mock card generation for Reminder, Calendar, Note, Shopping, and Job cards
- Editable card result screen
- Local in-memory inbox
- Markdown export
- Mock Reminder and Calendar creation services
- Prototype info and local reset screen

## Main Flow

1. Home shows recent saved cards and mock credits.
2. User taps `New Card`.
3. User adds an image with camera or photo import.
4. User selects a card type or Auto.
5. User taps Analyze.
6. `MockVisionAnalyzer` creates a `VisionUnderstandingContext`.
7. `MockCardGenerator` creates an `ActionCard`.
8. User edits the generated fields.
9. User can save, create mock Reminder/Calendar actions, copy Markdown, archive, or delete.

## Architecture

CaptureFlow uses a lightweight MVVM structure with protocol-oriented services. The current implementations are mock/local, but the protocol boundaries are designed so real services can replace them later.

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

  Repositories/

  Features/
    Home/
    Capture/
    Analysis/
    CardResult/
    CardDetail/
    Settings/
```

## Module Responsibilities

`App`
: Dependency composition and navigation route definitions. `AppContainer.prototype()` wires all mock services.

`DesignSystem`
: Shared colors, typography, spacing, rounded card containers, buttons, badges, empty states, loading steps, and image preview components.

`Domain`
: Pure app models and export logic. This layer should not import SwiftUI, UIKit, network SDKs, EventKit, Firebase, RevenueCat, or OpenAI SDKs.

`Services`
: Protocols and mock service implementations for vision analysis, card generation, credits, reminder creation, and calendar creation.

`Repositories`
: Local card persistence boundary. The prototype uses `InMemoryCardRepository`; SwiftData can replace it later behind the same `CardRepository` protocol.

`Features`
: SwiftUI screens and view models grouped by user-facing workflow.

## Core Protocols

- `VisionAnalyzing`
- `CardGenerating`
- `CardRepository`
- `ReminderCreating`
- `CalendarCreating`
- `CreditProviding`

Current implementations:

- `MockVisionAnalyzer`
- `MockCardGenerator`
- `InMemoryCardRepository`
- `MockReminderCreator`
- `MockCalendarCreator`
- `MockCreditProvider`

Future replacements:

- `MockVisionAnalyzer` -> `CloudVisionAnalyzer`
- `MockCardGenerator` -> `AppleFoundationCardGenerator`
- `MockCreditProvider` -> `RevenueCat + backend credit provider`
- `InMemoryCardRepository` -> `SwiftDataCardRepository`
- Mock external action services -> EventKit-backed services

## Design Direction

- Dark mode first
- Black and orange palette
- Rounded card-based UI
- Premium AI utility feel
- Focused workflow, not a traditional todo app

Key colors:

- Background: `#0B0B0D`
- Surface: `#17171A`
- Secondary Surface: `#222228`
- Primary Orange: `#FF7A1A`
- Orange Highlight: `#FF9F45`
- Text Primary: `#F5F5F7`
- Text Secondary: `#A1A1AA`
- Border: `#2F2F36`

## Build

```sh
xcodebuild -project CaptureFlow.xcodeproj -scheme CaptureFlow -destination 'generic/platform=iOS Simulator' build
```

The current build may show an AppIntents metadata warning because the app does not use AppIntents. That warning is unrelated to prototype behavior.

## Current Non-Goals

Do not add these in the local prototype unless the scope explicitly changes:

- RevenueCat
- Firebase
- OpenAI API
- Real backend
- Real cloud vision
- Real account login
- Real cloud sync
- Real credit accounting

## Development Notes

- Keep feature code small and workflow-oriented.
- Prefer existing design system components before adding new UI primitives.
- Keep domain models pure and Codable.
- Add real services behind existing protocols instead of changing feature screens directly.
- Preserve the local prototype path even when adding real integrations later.
