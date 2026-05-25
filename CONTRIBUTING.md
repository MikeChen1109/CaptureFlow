# Contributing

Thanks for taking the time to improve CaptureFlow.

## Project Direction

CaptureFlow is an open-source iOS tool for turning captured visual context into actionable insight cards. Contributions should keep the app easy to run, inspect, and adapt.

Good contribution areas:

- SwiftUI workflow polish
- Domain model and repository improvements
- Local persistence behind `CardRepository`
- On-device or mock-safe service implementations
- Tests for card generation, custom fields, exports, and action state
- Documentation that helps contributors understand the architecture

Discuss larger scope changes before implementing them, especially new service dependencies, persistence strategies, or data flows that send user content off device.

## Development

Requirements:

- Xcode 26.3 or newer
- iOS 18 simulator runtime or newer

Build from the repository root:

```sh
xcodebuild -project CaptureFlow.xcodeproj -scheme CaptureFlow -destination 'generic/platform=iOS Simulator' build
```

Run tests:

```sh
xcodebuild test -project CaptureFlow.xcodeproj -scheme CaptureFlow -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max,OS=18.6'
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
