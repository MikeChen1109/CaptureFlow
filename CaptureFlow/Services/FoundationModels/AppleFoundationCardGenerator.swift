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
                    
                    let response = try await session.respond(
                        to: Self.contentPrompt(for: context),
                        generating: AppleFoundationGeneratedCardContent.self,
                        options: Self.generationOptions
                    )
                    let content = try response.content.insightCard()
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
        from content: GeneratedInsightCard,
        context: VisionUnderstandingContext
    ) -> ActionCard {
        let baseCard = MockCardGenerator.placeholderCard(from: context, insight: content)
        let summary = content.summary ?? content.sections.first?.content ?? context.sceneSummary
        
        switch baseCard {
        case .note(var note):
            note.title = content.title
            note.summary = summary
            note.bullets = content.sections
                .filter { $0.kind == .checklist || $0.kind == .suggestedActions }
                .map(\.title)
            note.metadata.updatedAt = .now
            return .note(note)
        case .reminder(var reminder):
            reminder.title = content.title
            reminder.notes = summary
            reminder.location = context.entityValues(for: .location).first
            reminder.dueDate = context.firstDetectedDate
            reminder.metadata.updatedAt = .now
            return .reminder(reminder)
        case .calendar(var calendar):
            let startDate = context.firstDetectedDate ?? calendar.startDate
            calendar.title = content.title
            calendar.startDate = startDate
            calendar.endDate = max(calendar.endDate, startDate.addingTimeInterval(60 * 60))
            calendar.location = context.entityValues(for: .location).first
            calendar.notes = summary
            calendar.metadata.updatedAt = .now
            return .calendar(calendar)
        case .shopping(var shopping):
            shopping.productName = content.title
            shopping.price = context.entityValues(for: .price).first
            shopping.merchant = context.entityValues(for: .store).first
            shopping.offer = context.entityValues(for: .promotion).first
            shopping.notes = summary
            shopping.metadata.updatedAt = .now
            return .shopping(shopping)
        case .job(var job):
            job.company = context.entityValues(for: .company).first ?? job.company
            job.role = content.title
            job.skills = context.entityValues(for: .skill)
            job.contact = context.entityValues(for: .contact).first
            job.detail = summary
            job.notes = summary
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
    You are an assistant that turns screenshot analysis context into useful, concise insight cards.
    
    Your job is not to summarize everything.
    Your job is to decide what information is useful for the user.
    
    Use the provided context as the only factual source.
    Do not invent people, dates, locations, prices, companies, stores, URLs, contact details, salary, deadlines, or attendees.
    
    Rules:
    - Do not force a fixed template.
    - Generate only sections that are useful.
    - Generate between 1 and 5 sections.
    - If the context has little value, say so clearly.
    - Prefer practical next steps over generic summaries.
    - Do not invent details not present in the context.
    - If important information is missing, include a missing information section.
    - Keep each section concise.
    - Section kind is for UI presentation only, not product classification.
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
            "Build a GeneratedInsightCard from the provided local image understanding context.",
            "",
            "Use the provided context as the only factual source.",
            "Decide what information is genuinely useful for this screenshot.",
            "Do not invent people, dates, locations, prices, companies, stores, URLs, contact details, salary, deadlines, attendees, or tasks.",
            "",
            "Output quality goals:",
            "- Make the result useful as a user-facing insight card, not a raw extraction.",
            "- Be concise, specific, practical, and action-oriented.",
            "- Prefer practical next steps over generic summaries.",
            "- Generate only sections that are useful.",
            "- Generate between 1 and 5 sections.",
            "- Do not force checklist, draft, or actions when they are not useful.",
            "- Do not include filler or meta commentary.",
            "- Do not start with generic phrases like \"This image appears to show\" unless uncertainty is important.",
            "- If useful information is missing or uncertain, include one missingInfo section instead of guessing.",
            "",
            "Required output shape:",
            "",
            "title:",
            "- Short, specific title based only on context.",
            "",
            "usefulness:",
            "- useful: enough context to provide clear value.",
            "- partiallyUseful: some value exists, but important context is missing.",
            "- lowInformation: visible context is too thin for a useful card.",
            "- unclear: the screenshot purpose cannot be inferred.",
            "",
            "confidence:",
            "- 0.0 to 1.0 based on how well supported the card is by the context.",
            "",
            "summary:",
            "- Optional. Include only when it adds value beyond the sections.",
            "",
            "sections:",
            "- Generate 1 to 5 concise sections.",
            "- Allowed section kinds: summary, keyDetails, suggestedActions, checklist, draft, missingInfo, warning, tags, note.",
            "- Use missingInfo when key details required for useful action are absent.",
            "- Use draft only when a ready-to-send reply or reusable text is clearly useful.",
            "- Use checklist only when the screenshot actually contains or implies checkable tasks.",
            "- Use suggestedActions for practical next steps supported by context.",
            "- Use tags for compact labels only when they help retrieval.",
            "- priority starts at 1; lower priority appears first.",
            "",
            "Context:",
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
    var title: String
    var usefulness: AppleFoundationInsightUsefulness
    var confidence: Double
    var summary: String
    var sections: [AppleFoundationInsightSection]
}

@available(iOS 26.0, *)
@Generable
private struct AppleFoundationInsightSection {
    var kind: AppleFoundationInsightSectionKind
    var title: String
    var content: String
    var priority: Int
}

@available(iOS 26.0, *)
@Generable
private enum AppleFoundationInsightUsefulness {
    case useful
    case partiallyUseful
    case lowInformation
    case unclear
}

@available(iOS 26.0, *)
@Generable
private enum AppleFoundationInsightSectionKind {
    case summary
    case keyDetails
    case suggestedActions
    case checklist
    case draft
    case missingInfo
    case warning
    case tags
    case note
}

@available(iOS 26.0, *)
private extension AppleFoundationGeneratedCardContent {
    func insightCard() throws -> GeneratedInsightCard {
        let sections = mappedSections
        guard let title = title.nonEmpty, !sections.isEmpty else {
            throw ServiceError.invalidGeneratedCard
        }
        
        return GeneratedInsightCard(
            title: title,
            usefulness: usefulness.insightUsefulness,
            confidence: confidence.clamped(to: 0...1),
            summary: summary.nonEmpty,
            sections: sections
        )
    }
    
    private var mappedSections: [InsightSection] {
        sections
            .compactMap(\.insightSection)
            .sorted { $0.priority < $1.priority }
            .prefix(5)
            .map { $0 }
    }
}

@available(iOS 26.0, *)
private extension AppleFoundationInsightSection {
    var insightSection: InsightSection? {
        guard let title = title.nonEmpty,
              let content = content.nonEmpty
        else {
            return nil
        }
        
        return InsightSection(
            kind: kind.insightSectionKind,
            title: title,
            content: content,
            priority: max(1, priority)
        )
    }
}

@available(iOS 26.0, *)
private extension AppleFoundationInsightUsefulness {
    var insightUsefulness: InsightUsefulness {
        switch self {
        case .useful:
            .useful
        case .partiallyUseful:
            .partiallyUseful
        case .lowInformation:
            .lowInformation
        case .unclear:
            .unclear
        }
    }
}

@available(iOS 26.0, *)
private extension AppleFoundationInsightSectionKind {
    var insightSectionKind: InsightSectionKind {
        switch self {
        case .summary:
            .summary
        case .keyDetails:
            .keyDetails
        case .suggestedActions:
            .suggestedActions
        case .checklist:
            .checklist
        case .draft:
            .draft
        case .missingInfo:
            .missingInfo
        case .warning:
            .warning
        case .tags:
            .tags
        case .note:
            .note
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
