import Foundation

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
struct AppleFoundationCardGenerator: CardGenerating {
    private let model: SystemLanguageModel
    private let fallbackGenerator: any CardGenerating
    
    init(
        model: SystemLanguageModel = .default,
        fallbackGenerator: any CardGenerating = MockCardGenerator()
    ) {
        self.model = model
        self.fallbackGenerator = fallbackGenerator
    }
    
    func streamGeneratedContent(
        from context: VisionUnderstandingContext
    ) -> AsyncThrowingStream<CardGenerationEvent, Error> {
        guard model.isAvailable else {
            logGenerationMode(.fallbackMock)
            return fallbackGenerator.streamGeneratedContent(from: context)
        }
        
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    logGenerationMode(.foundationModels)
                    let session = LanguageModelSession(
                        model: model,
                        instructions: Self.contentInstructions
                    )
                    
                    let stream = session.streamResponse(
                        to: Self.contentPrompt(for: context),
                        generating: AppleFoundationGeneratedCardContent.self,
                        options: Self.generationOptions
                    )
                    
                    var latestDraft: AppleFoundationGeneratedCardContent.PartiallyGenerated?
                    
                    for try await partialResponse in stream {
                        latestDraft = partialResponse.content
                        continuation.yield(.partialContent(partialResponse.content.generatedContentPartial))
                    }
                    
                    guard let latestDraft else {
                        throw ServiceError.invalidGeneratedCard
                    }
                    
                    let content = try latestDraft.generatedContent()
                    let card = makeActionCard(from: content, context: context)
                    
                    continuation.yield(.completed(card: card, content: content))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
    
    private func makeActionCard(
        from content: GeneratedCardContent,
        context: VisionUnderstandingContext
    ) -> ActionCard {
        let baseCard = MockCardGenerator.placeholderCard(from: context)
        
        switch baseCard {
        case .note(var note):
            note.title = context.fallbackTitle
            note.summary = content.summary
            note.bullets = content.planSteps.map(\.title).nonEmpty(or: note.bullets)
            note.items = content.recommendedActions.map(\.title)
            note.metadata.updatedAt = .now
            return .note(note)
        case .reminder(var reminder):
            reminder.title = context.fallbackTitle
            reminder.notes = content.summary
            reminder.location = context.entityValues(for: .location).first
            reminder.dueDate = context.firstDetectedDate
            reminder.metadata.updatedAt = .now
            return .reminder(reminder)
        case .calendar(var calendar):
            let startDate = context.firstDetectedDate ?? calendar.startDate
            calendar.title = context.fallbackTitle
            calendar.startDate = startDate
            calendar.endDate = max(calendar.endDate, startDate.addingTimeInterval(60 * 60))
            calendar.location = context.entityValues(for: .location).first
            calendar.notes = content.summary
            calendar.metadata.updatedAt = .now
            return .calendar(calendar)
        case .shopping(var shopping):
            shopping.productName = context.fallbackTitle
            shopping.price = context.entityValues(for: .price).first
            shopping.merchant = context.entityValues(for: .store).first
            shopping.offer = context.entityValues(for: .promotion).first
            shopping.notes = content.summary
            shopping.metadata.updatedAt = .now
            return .shopping(shopping)
        case .job(var job):
            job.company = context.entityValues(for: .company).first ?? job.company
            job.role = context.fallbackTitle
            job.skills = context.entityValues(for: .skill)
            job.contact = context.entityValues(for: .contact).first
            job.detail = content.planSteps.map(\.detail).joined(separator: "\n")
            job.notes = content.summary
            job.date = context.firstDetectedDate
            job.metadata.updatedAt = .now
            return .job(job)
        }
    }
    
    private enum GenerationMode: String {
        case foundationModels = "FoundationModels"
        case fallbackMock = "Fallback(Mock)"
    }
    
    private func logGenerationMode(_ mode: GenerationMode) {
#if DEBUG
        print("[CaptureFlow][CardGenerator] Mode=\(mode.rawValue)")
#endif
    }
    
    private static let contentInstructions = """
    You turn local image understanding context into GeneratedCardContent for CaptureFlow.
    
    Use the provided context as the only factual source.
    You may rewrite, combine, prioritize, and simplify supported information to make the result useful.
    Do not invent people, dates, locations, prices, companies, stores, URLs, contact details, salary, deadlines, or attendees.
    
    Write for a user-facing action card:
    - concise
    - practical
    - specific
    - action-oriented
    - no filler
    - no generic assistant phrasing
    
    If useful information is missing or uncertain, put it in missingInfo.
    If a field has no supported content, return an empty string or an empty array.
    """
    
    private static let generationOptions = GenerationOptions(
        sampling: .greedy,
        temperature: 0.2
    )
    
    private static func contentPrompt(for context: VisionUnderstandingContext) -> String {
        let visibleText = joinedPromptValues(context.visibleText)
        let missingInfo = joinedPromptValues(context.missingInfo)
        let evidence = joinedPromptValues(context.evidence)
        let visualObjects = joinedPromptValues(context.visualObjects)
        let constraints = joinedPromptValues(context.constraints)
        
        var lines: [String] = [
            "Build GeneratedCardContent from the provided local image understanding context.",
            "",
            "The selected card type is represented by requestedCardType when it is not auto.",
            "Use the provided context as the only factual source.",
            "You may rewrite, combine, prioritize, and simplify supported information to make the result useful.",
            "Do not invent people, dates, locations, prices, companies, stores, URLs, contact details, salary, deadlines, attendees, or tasks.",
            "",
            "Output quality goals:",
            "- Make the result useful as a user-facing action card, not a raw extraction.",
            "- Be concise, specific, practical, and action-oriented.",
            "- Prefer concrete details over generic descriptions.",
            "- Do not include filler or meta commentary.",
            "- Do not start with generic phrases like \"This image appears to show\" unless uncertainty is important.",
            "- If a field has no supported content, return an empty string or an empty array.",
            "- If useful information is missing or uncertain, put that gap in missingInfo instead of guessing.",
            "",
            "Required output shape:",
            "",
            "summary:",
            "- First summarize what the image is about.",
            "- Include important visible facts such as product, price, and promotion.",
            "- Mention a next action only in the final sentence and only when supported.",
            "",
            "planTitle:",
            "- Use recommendedPlanTitle when it is suitable.",
            "- You may lightly refine wording for clarity.",
            "- Do not add new facts.",
            "",
            "planSteps:",
            "- Create practical steps based mainly on possibleActions, requestedCardType, and recommendedPlanTitle.",
            "- You may reference entities, missingInfo, and constraints only when needed to make the steps clearer or more useful.",
            "- If an action depends on missing information, turn it into a clarification step instead of dropping it.",
            "- Do not create steps that require unsupported facts.",
            "",
            "keyDetails:",
            "- Use entities as the primary factual source.",
            "- You may also include important visibleText items when they are clear product facts.",
            "- Rewrite details into concise, user-facing labels and values.",
            "- Do not include evidence explanations here.",
            "",
            "missingInfo:",
            "- Include only information that is explicitly missing, uncertain, or constrained by missingInfo and constraints.",
            "- Rewrite raw keywords into short user-facing sentences.",
            "- Prefer concrete gaps such as \"Store name is not visible\" over raw labels such as \"store\".",
            "- If an action depends on missing information, mention the missing requirement here instead of guessing.",
            "- Do not add generic missing items.",
            "",
            "recommendedActions:",
            "- Use possibleActions as the factual source.",
            "- Rewrite them into clear action labels or short actionable sentences.",
            "- Do not add new actions.",
            "",
            "sourceReasoning:",
            "- Use evidence only.",
            "- Briefly explain what visible clues support the generated content.",
            "- Do not include hidden assumptions.",
            "",
            "Context:",
            "Requested card type: \(context.requestedCardType.rawValue)",
            "Resolved card type: \(context.resolvedCardType.rawValue)",
            "Scene title: \(context.sceneTitle)",
            "Visible text: \(visibleText)",
            "Entities: \(context.entities.promptLines)",
            "Possible actions: \(context.possibleActions.promptLines)",
            "Missing info: \(missingInfo)",
            "Recommended plan title: \(context.recommendedPlanTitle)",
            "Evidence: \(evidence)"
        ]
        
        if let sceneSummary = context.sceneSummary.nonEmpty {
            lines.append("Scene summary: \(sceneSummary)")
        }
        
        if let userIntentGuess = context.userIntentGuess.nonEmpty {
            lines.append("User intent guess: \(userIntentGuess)")
        }
        
        if visualObjects != "None" {
            lines.append("Visual objects: \(visualObjects)")
        }
        
        if let layoutDescription = context.layoutDescription.nonEmpty {
            lines.append("Layout description: \(layoutDescription)")
        }
        
        if constraints != "None" {
            lines.append("Constraints: \(constraints)")
        }
        
        lines.append("Confidence score: \(context.confidenceScore)")
        
        return lines.joined(separator: "\n")
    }
    
    private static func joinedPromptValues(_ values: [String]) -> String {
        let cleaned = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return cleaned.isEmpty ? "None" : cleaned.joined(separator: " | ")
    }
}

@available(iOS 26.0, *)
@Generable
private struct AppleFoundationGeneratedCardContent {
    var summary: String
    var planTitle: String
    var planSteps: [AppleFoundationGeneratedPlanStep]
    var keyDetails: [AppleFoundationGeneratedField]
    var recommendedActions: [AppleFoundationGeneratedAction]
    var missingInfo: [String]
    var sourceReasoning: [String]
}

@available(iOS 26.0, *)
@Generable
private struct AppleFoundationGeneratedPlanStep {
    var title: String
    var detail: String
    var actionType: AppleFoundationGeneratedActionType
}

@available(iOS 26.0, *)
@Generable
private struct AppleFoundationGeneratedField {
    var label: String
    var value: String
    var type: AppleFoundationGeneratedEntityType
    var confidence: Double
}

@available(iOS 26.0, *)
@Generable
private struct AppleFoundationGeneratedAction {
    var title: String
    var description: String
    var actionType: AppleFoundationGeneratedActionType
}

@available(iOS 26.0, *)
@Generable
private enum AppleFoundationGeneratedActionType {
    case save
    case reminder
    case calendar
    case copy
    case share
    case compare
    case followUp
    case custom
}

@available(iOS 26.0, *)
@Generable
private enum AppleFoundationGeneratedEntityType {
    case product
    case price
    case promotion
    case store
    case date
    case time
    case location
    case company
    case role
    case skill
    case url
    case contact
    case note
    case event
    case unknown
}

@available(iOS 26.0, *)
private extension AppleFoundationGeneratedCardContent.PartiallyGenerated {
    var generatedContentPartial: GeneratedContentPartial {
        GeneratedContentPartial(
            summary: summary.nonEmpty,
            planTitle: planTitle.nonEmpty,
            planSteps: mappedPlanSteps,
            recommendedActions: mappedRecommendedActions,
            keyDetails: mappedKeyDetails,
            missingInfo: mappedMissingInfo,
            sourceReasoning: mappedSourceReasoning
        )
    }
    
    func generatedContent() throws -> GeneratedCardContent {
        guard let summary = summary.nonEmpty,
              let planTitle = planTitle.nonEmpty
        else {
            throw ServiceError.invalidGeneratedCard
        }
        
        let planSteps = mappedPlanSteps
        let recommendedActions = mappedRecommendedActions
        
        guard !planSteps.isEmpty, !recommendedActions.isEmpty else {
            throw ServiceError.invalidGeneratedCard
        }
        
        return GeneratedCardContent(
            summary: summary,
            planTitle: planTitle,
            planSteps: planSteps,
            keyDetails: mappedKeyDetails,
            recommendedActions: recommendedActions,
            missingInfo: mappedMissingInfo,
            sourceReasoning: mappedSourceReasoning,
            personalNotePlaceholder: "Add your own note..."
        )
    }
    
    private var mappedPlanSteps: [GeneratedPlanStep] {
        guard let planSteps else { return [] }
        return planSteps.compactMap(\.generatedPlanStep)
    }
    
    private var mappedRecommendedActions: [GeneratedAction] {
        guard let recommendedActions else { return [] }
        return recommendedActions.compactMap(\.generatedAction)
    }
    
    private var mappedKeyDetails: [GeneratedField] {
        guard let keyDetails else { return [] }
        return keyDetails.compactMap(\.generatedField)
    }
    
    private var mappedMissingInfo: [String] {
        guard let missingInfo else { return [] }
        return missingInfo.compactMap(\.nonEmpty)
    }
    
    private var mappedSourceReasoning: [String] {
        guard let sourceReasoning else { return [] }
        return sourceReasoning.compactMap(\.nonEmpty)
    }
    
}

@available(iOS 26.0, *)
private extension AppleFoundationGeneratedPlanStep.PartiallyGenerated {
    var generatedPlanStep: GeneratedPlanStep? {
        guard let title = title.nonEmpty ?? detail.nonEmpty else {
            return nil
        }
        
        return GeneratedPlanStep(
            title: title,
            detail: detail.nonEmpty(or: title),
            actionType: actionType?.visionActionType ?? .custom
        )
    }
}

@available(iOS 26.0, *)
private extension AppleFoundationGeneratedAction.PartiallyGenerated {
    var generatedAction: GeneratedAction? {
        guard let title = title.nonEmpty else {
            return nil
        }
        
        return GeneratedAction(
            title: title,
            description: description.nonEmpty(or: title),
            actionType: actionType?.visionActionType ?? .custom
        )
    }
}

@available(iOS 26.0, *)
private extension AppleFoundationGeneratedField.PartiallyGenerated {
    var generatedField: GeneratedField? {
        guard let label = label.nonEmpty,
              let value = value.nonEmpty
        else {
            return nil
        }
        
        return GeneratedField(
            label: label,
            value: value,
            type: type?.visionEntityType ?? .unknown,
            confidence: (confidence ?? 0.5).clamped(to: 0...1)
        )
    }
}

@available(iOS 26.0, *)
private extension AppleFoundationGeneratedActionType {
    var visionActionType: VisionActionType {
        switch self {
        case .save:
                .save
        case .reminder:
                .reminder
        case .calendar:
                .calendar
        case .copy:
                .copy
        case .share:
                .share
        case .compare:
                .compare
        case .followUp:
                .followUp
        case .custom:
                .custom
        }
    }
}

@available(iOS 26.0, *)
private extension AppleFoundationGeneratedEntityType {
    var visionEntityType: VisionEntityType {
        switch self {
        case .product:
                .product
        case .price:
                .price
        case .promotion:
                .promotion
        case .store:
                .store
        case .date:
                .date
        case .time:
                .time
        case .location:
                .location
        case .company:
                .company
        case .role:
                .role
        case .skill:
                .skill
        case .url:
                .url
        case .contact:
                .contact
        case .note:
                .note
        case .event:
                .event
        case .unknown:
                .unknown
        }
    }
}

#endif

private extension VisionUnderstandingContext {
    var fallbackTitle: String {
        sceneTitle.nonEmpty(or: recommendedPlanTitle.nonEmpty(or: visibleText.first ?? "Untitled card"))
    }
    
    var firstDetectedDate: Date? {
        let values = entityValues(for: .date) + entityValues(for: .time)
        return values.compactMap(Date.captureFlowDate(from:)).first
    }
    
    func entityValues(for type: VisionEntityType) -> [String] {
        entities
            .filter { $0.type == type }
            .compactMap { $0.value.nonEmpty }
    }
}

private extension [VisionEntity] {
    var promptLines: String {
        let values = map {
            "\($0.type.rawValue): \($0.label)=\($0.value) (confidence \($0.confidence))"
        }
        
        return values.isEmpty ? "None" : values.joined(separator: " | ")
    }
}

private extension [VisionActionHint] {
    var promptLines: String {
        let values = map {
            "\($0.actionType.rawValue): \($0.title) - \($0.description)"
        }
        
        return values.isEmpty ? "None" : values.joined(separator: " | ")
    }
}

private extension String? {
    nonisolated var nonEmpty: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty
        else {
            return nil
        }
        
        return value
    }
    
    nonisolated func nonEmpty(or fallback: String) -> String {
        nonEmpty ?? fallback
    }
}

private extension String {
    nonisolated var nonEmpty: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
    
    nonisolated func nonEmpty(or fallback: String) -> String {
        nonEmpty ?? fallback
    }
}

private extension [String] {
    nonisolated func nonEmpty(or fallback: [String]) -> [String] {
        let values = compactMap { $0.nonEmpty }
        return values.isEmpty ? fallback : values
    }
}

private extension Double {
    nonisolated func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private extension Date {
    nonisolated static func captureFlowDate(from value: String?) -> Date? {
        guard let value = value?.nonEmpty else {
            return nil
        }
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]
        
        if let date = isoFormatter.date(from: value) {
            return date
        }
        
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: value) {
            return date
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(identifier: "Asia/Taipei")
        
        for format in [
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd"
        ] {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: value) {
                return date
            }
        }
        
        return nil
    }
}
