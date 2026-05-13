# CaptureFlow Streaming Generation Skill

Use this skill when working on CaptureFlow's Card Result generation flow, Foundation Models generation, mock card generation, or progressive AI result UI.

## Goal

CaptureFlow's Card Result screen should feel like real progressive AI generation, similar to Apple's Foundation Models itinerary demo.

The user should see content appear from top to bottom while generation is happening:

1. Summary
2. Plan / Checklist
3. Recommended Actions
4. Draft Output
5. Key Details
6. Missing Info
7. Personal Note
8. Final action buttons after completion

The UI must not feel like the app waited for a full response and then replayed a fake animation.

## Core Rule

Do not implement the real generation path by generating all content first and then using `Task.sleep`, timers, delayed dispatch, or fake staged reveal to show sections one by one.

Avoid this anti-pattern:

```swift
let content = try await generator.generateContent(from: context)
await revealSummary()
await revealPlan()
await revealRecommendedActions()
await revealDraft()
await revealKeyDetails()
```

This waits for the full result and then fake-reveals it. That is not the desired behavior.

## Correct Architecture

Use one event-driven streaming pipeline.

Preferred flow:

```text
CardGenerating
  -> AsyncThrowingStream<CardGenerationEvent, Error>
  -> CardResultGenerationView
  -> CardResultViewModel.applyPartialContent(...)
  -> GeneratedSectionState
  -> SwiftUI section cards
```

The UI should update from incoming generation events.

Do not split the experience into:

1. A temporary summary-only generation screen
2. A final result screen that fake-reveals completed content

The result UI should appear immediately and update progressively.

## Suggested Event Model

Use or adapt an app-level generation event model like this:

```swift
enum CardGenerationEvent: Sendable {
    case partialContent(GeneratedContentPartial)
    case completed(card: ActionCard, content: GeneratedCardContent)
}
```

Use or adapt a partial content model like this:

```swift
struct GeneratedContentPartial: Equatable, Sendable {
    var summary: String?
    var planTitle: String?
    var planSteps: [GeneratedPlanStep]?
    var recommendedActions: [GeneratedAction]?
    var draftOutput: GeneratedDraft?
    var keyDetails: [GeneratedField]?
    var missingInfo: [String]?
    var sourceReasoning: [String]?
    var personalNotePlaceholder: String?
}
```

The exact names can change if the existing codebase already has suitable types, but the behavior should remain section-level progressive streaming.

## CardGenerating Rules

Prefer a streaming API for progressive result UI:

```swift
func streamGeneratedContent(
    from context: VisionUnderstandingContext
) -> AsyncThrowingStream<CardGenerationEvent, Error>
```

The stream should emit partial content as soon as it becomes available.

Expected event sequence:

```text
partialContent(summary)
partialContent(planTitle / planSteps)
partialContent(recommendedActions)
partialContent(draftOutput)
partialContent(keyDetails)
partialContent(missingInfo)
partialContent(personalNotePlaceholder)
completed(card, content)
```

The final `completed` event should provide the final normalized `ActionCard` and `GeneratedCardContent`.

## Foundation Models Rules

When using Apple Foundation Models:

- Keep `#if canImport(FoundationModels)`.
- Keep `@available(iOS 26.0, *)` or equivalent availability guards.
- Use `LanguageModelSession.streamResponse(...)` when implementing progressive generation.
- Stream content sections, not only a thin title/summary partial.
- Map `PartiallyGenerated` output into `GeneratedContentPartial`.
- Use the final generated output to normalize the final `ActionCard` and `GeneratedCardContent`.
- Preserve mock fallback behavior when Foundation Models is unavailable.

Do not wait for the full Foundation Models response before showing Plan, Actions, Draft, or Key Details.

## Mock Generator Rules

Mock generation may simulate streaming, but it must use the same event pipeline as the real Foundation Models path.

Correct mock behavior:

```text
MockCardGenerator
  -> emits partialContent(summary)
  -> emits partialContent(plan)
  -> emits partialContent(actions)
  -> emits partialContent(draft)
  -> emits partialContent(keyDetails)
  -> emits partialContent(missingInfo)
  -> emits completed(card, content)
```

Avoid:

```text
MockCardGenerator generates full content
CardResultViewModel sleeps and reveals completed content
```

The mock path should validate the same UI behavior that the real Foundation Models path uses.

## ViewModel Rules

`CardResultViewModel` should be driven by incoming generation events.

Prefer methods like:

```swift
@MainActor
func applyPartialContent(_ partial: GeneratedContentPartial)

@MainActor
func completeGeneration(card: ActionCard, content: GeneratedCardContent)

@MainActor
func failGeneration(_ error: Error)
```

`applyPartialContent` should:

- Mark a section as `.generating` when partial content starts appearing.
- Update section content incrementally.
- Preserve already visible content.
- Keep completed sections visible while later sections continue generating.
- Avoid resetting the full section list unnecessarily.
- Avoid using hardcoded sleep delays for the real generation path.

`completeGeneration` should:

- Store the final `ActionCard`.
- Store or apply the final `GeneratedCardContent`.
- Mark all available sections as `.completed`.
- Set generation as complete.
- Enable final action buttons.

## Generated Section State Rules

Use `GeneratedSectionState` or an equivalent model to represent section state.

Expected section statuses:

```swift
enum GeneratedSectionStatus: String, Sendable {
    case waiting
    case generating
    case completed
}
```

Status meaning:

- `.waiting`: no meaningful content has arrived yet.
- `.generating`: partial content exists or the model is currently generating this section.
- `.completed`: final content is available or generation has completed.

Rules:

- Do not mark every section as completed before generation is complete.
- Do not show action buttons while generation is still running.
- Completed sections should stay visible.
- Waiting sections may be hidden or shown as subtle placeholders depending on the UI design.

## View Rules

The result screen should be visible while generation is running.

Expected behavior:

- Header appears early.
- Summary appears when partial summary exists.
- Plan appears when partial plan data exists.
- Recommended Actions appear when partial action data exists.
- Draft Output appears when partial draft data exists.
- Key Details appear when partial field/detail data exists.
- Missing Info appears when partial missing info exists.
- Personal Note appears when placeholder is available or generation is near completion.
- Action buttons appear only after generation completes.

Animation is allowed, but animation should visualize real state changes. It should not replace real streaming.

## Mapping Rules

When converting Foundation Models generated content into app models, use the model-generated values.

If the generated model contains fields like:

```swift
var planSteps: [AppleFoundationGeneratedPlanStep]
var keyDetails: [AppleFoundationGeneratedField]
var recommendedActions: [AppleFoundationGeneratedAction]
var missingInfo: [String]
var sourceReasoning: [String]
```

Then map them into `GeneratedCardContent`.

Do not discard generated values and replace them with context fallback values unless the generated values are empty or invalid.

Correct direction:

```swift
GeneratedCardContent(
    summary: summary,
    planTitle: planTitle,
    planSteps: planSteps.map { ... },
    keyDetails: keyDetails.map { ... },
    recommendedActions: recommendedActions.map { ... },
    draftOutput: draftOutput.map { ... },
    missingInfo: missingInfo,
    sourceReasoning: sourceReasoning,
    personalNotePlaceholder: personalNotePlaceholder
)
```

Fallbacks such as `context.generatedPlanSteps`, `context.generatedKeyDetails`, or `GeneratedCardContent.fallback(from:)` should only be used when generated values are missing.

## Refactor Checklist

When fixing the current progressive generation flow, follow this order:

1. Inspect `CardResultGenerationView`.
2. Inspect `CardResultViewModel`.
3. Inspect `AppleFoundationCardGenerator`.
4. Inspect `MockCardGenerator`.
5. Inspect `GeneratedSectionViews`.
6. Find any fake reveal logic using `Task.sleep`.
7. Add or update a section-level partial content event model.
8. Update mock generation to emit partial events.
9. Update Foundation Models generation to stream partial content.
10. Update the view model to apply partial events.
11. Update the result view to render from section state.
12. Hide final action buttons until completion.
13. Remove fake reveal logic from the real generation path.
14. Build and verify.

## Debugging Checklist

When the generation UI still feels fake, check:

1. Is the UI waiting for `.completed` before showing most sections?
2. Is only title/summary streamed?
3. Is `GeneratedCardContent.fallback(from:)` replacing model-generated content?
4. Is `CardResultViewModel` using `Task.sleep` to reveal completed content?
5. Is there a temporary summary-only screen before the real result view?
6. Are Foundation Models partial outputs mapped into app state?
7. Does mock mode use the same event model as real Foundation Models mode?
8. Are final action buttons hidden until generation completes?

## Non-Goals

Do not add these while working on streaming generation unless explicitly requested:

- OpenAI API
- Backend streaming
- Firebase
- RevenueCat
- Real Cloud Vision
- Real login
- Real sync
- Real Reminder or Calendar integrations
- Full app architecture rewrite
- Unrelated UI redesign

## Build Command

Use this command to verify the app builds:

```sh
xcodebuild -project CaptureFlow.xcodeproj -scheme CaptureFlow -destination 'generic/platform=iOS Simulator' build
```

An AppIntents metadata warning is expected and not a blocker unless AppIntents are introduced.

## Working Style

Act as a senior iOS architect and product-minded mobile engineer.

Prioritize:

- Real progressive generation behavior
- Small scoped changes
- Existing architecture compatibility
- Protocol-oriented replacement points
- Mock fallback safety
- Swift Concurrency correctness
- SwiftUI state clarity
- UI consistency with the existing black/orange design system

The target experience is Apple itinerary-demo-like progressive generation, not delayed replay of completed content.
