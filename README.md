<p align="center">
  <img src="CaptureFlow/Resources/Assets.xcassets/AppIcon.appiconset/1024.png" alt="CaptureFlow app icon" width="128">
</p>

# CaptureFlow

CaptureFlow is a local-first iOS app for turning captured visual context into useful insight cards. A user can capture or import an image, analyze it, generate an editable insight, save it to a local inbox, and turn supported insights into Reminders or Calendar events.

The project is being prepared as an open-source tool. It currently focuses on product flow, data boundaries, and UI feel rather than backend infrastructure.

## Current Scope

- SwiftUI app with a dark-mode-first interface
- Image capture from camera or Photos
- Local source-image persistence for newly imported images
- Mock image understanding through `MockVisionAnalyzer`
- Insight generation through `CardGenerating`
- Apple Foundation Models generation on iOS 26+ with mock fallback
- Saved insight inbox backed by `SavedInsightCard`
- Detail view with generated sections, source image context, Markdown export, archive, and delete
- EventKit-backed Reminder and Calendar creation
- External action state tracking through stored Reminder and Calendar identifiers
- Settings page for generated content and motion preferences
- In-memory repository boundary for future persistent storage

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

## Architecture

CaptureFlow uses lightweight MVVM with protocol-oriented service boundaries.

Core protocols:

- `VisionAnalyzing`
- `CardGenerating`
- `CardRepository`
- `ReminderCreating`
- `CalendarCreating`

Current implementations:

- `MockVisionAnalyzer`
- `AppleFoundationCardGenerator` on iOS 26+ when Foundation Models is available
- `MockCardGenerator` fallback
- `InMemoryCardRepository`
- `EventKitReminderCreator`
- `EventKitCalendarCreator`

Domain models should remain `Codable` and should not import SwiftUI, UIKit, EventKit, Firebase, RevenueCat, OpenAI SDKs, or network SDKs.

## Requirements

- Xcode 26.3 or newer
- iOS 26 simulator SDK

## Build

```sh
xcodebuild -project CaptureFlow.xcodeproj -scheme CaptureFlow -destination 'generic/platform=iOS Simulator' build
```

Run tests:

```sh
xcodebuild test -project CaptureFlow.xcodeproj -scheme CaptureFlow -destination 'platform=iOS Simulator,name=iPhone 17'
```

If your simulator name differs, replace the destination with an installed simulator.

## Open Source

- Contributions: [CONTRIBUTING.md](CONTRIBUTING.md)
- Code of conduct: [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- Security policy: [SECURITY.md](SECURITY.md)
- Roadmap: [docs/ROADMAP.md](docs/ROADMAP.md)
- License: [MIT](LICENSE)

## Non-Goals

Do not add these unless the project scope explicitly changes:

- Firebase
- OpenAI API
- Real backend
- Account login
- Cloud sync
- RevenueCat purchase flow
