# Roadmap

CaptureFlow is pre-release. This roadmap keeps the open-source direction explicit while preserving the current local-first app.

## Near Term

- Replace placeholder tests with focused domain, repository, and view model tests.
- Add file-backed or SwiftData persistence behind `CardRepository`.
- Improve Markdown export coverage.
- Expand mock analysis scenarios for screenshots, receipts, event flyers, shopping pages, and notes.
- Document how generated insight sections map to supported action cards.
- Wire settings into generation detail, tone, and motion behavior.

## Mid Term

- Add configurable on-device analysis and generation options.
- Add a share extension entry point.
- Add import/export support for saved insights.
- Improve accessibility across capture, review, and detail flows.
- Add CI once the required Xcode and iOS simulator versions are available on the target runner.

## Long Term

- Evaluate optional cloud sync with a clear privacy model.
- Support additional external actions through narrow service protocols.

## Non-Goals

- Firebase
- Account login
- Cloud sync
- RevenueCat purchase flow
- Network-only AI providers
