# Architecture

CaptureFlow uses a single Swift module with feature-oriented folders and protocol-based service boundaries. The current app is intentionally local-first so the product flow can be validated before backend, account, payment, or cloud dependencies are added.

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
    EventKit/
    FoundationModels/
    Mock/
    Models/
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
: Pure app models and export logic. Domain files should stay independent from SwiftUI, UIKit, EventKit, Firebase, RevenueCat, OpenAI SDKs, and network SDKs.

`Features`
: Workflow-specific SwiftUI screens and view models. Feature code can compose domain models, repositories, services, and design system primitives.

`Resources`
: Asset catalogs, launch screen resources, and future local resource files.

`Services`
: External capability boundaries and implementations for analysis, generation, reminders, and calendars.

## Core Protocols

- `VisionAnalyzing`
- `CardGenerating`
- `CardRepository`
- `ReminderCreating`
- `CalendarCreating`

## Current Implementations

- `MockVisionAnalyzer`
- `AppleFoundationCardGenerator` on iOS 26+ when Foundation Models is available
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

Keep this direction intact when adding production implementations. A new backend, storage system, or AI provider should be introduced behind an existing protocol or a small new protocol rather than being called directly from SwiftUI views.
