# Contributing

Thanks for taking the time to improve CaptureFlow.

## Project Direction

CaptureFlow is currently a local-first iOS app. Contributions should keep the app useful without introducing production-only dependencies too early.

Good contribution areas:

- SwiftUI workflow polish
- Domain model and repository improvements
- Local persistence behind `CardRepository`
- On-device or mock-safe service implementations
- Tests for card generation, custom fields, exports, and action state
- Documentation that helps contributors understand the architecture

Avoid adding these without an accepted design discussion:

- Backend services
- Account systems
- Firebase
- RevenueCat
- Network-only AI providers
- Cloud sync

## Development

Requirements:

- Xcode 26.3 or newer
- iOS 26 simulator SDK

Build from the repository root:

```sh
xcodebuild -project CaptureFlow.xcodeproj -scheme CaptureFlow -destination 'generic/platform=iOS Simulator' build
```

Run tests:

```sh
xcodebuild test -project CaptureFlow.xcodeproj -scheme CaptureFlow -destination 'platform=iOS Simulator,name=iPhone 17'
```

If your local simulator name differs, replace the destination with an installed simulator.

## Architecture Rules

- Keep domain models in `CaptureFlow/Domain` pure and `Codable`.
- Put persistence boundaries under `CaptureFlow/Data`.
- Add external integrations through protocols in `CaptureFlow/Services/Protocols`.
- Keep mock implementations available for previews, tests, and local development.
- Prefer existing design system components before adding new UI primitives.

## Pull Requests

- Keep PRs focused on one behavior or one structural cleanup.
- Include tests when changing domain logic, view models, repositories, or service behavior.
- Update `README.md` or `docs/` when public behavior or architecture changes.
- Do not commit `DerivedData`, `build/`, user schemes, or `.DS_Store`.
