import Foundation

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
struct AppleFoundationCardGenerator: CardGenerating {
    private let model: SystemLanguageModel
    private let fallback: MockCardGenerator

    init(
        model: SystemLanguageModel = .default,
        fallback: MockCardGenerator = MockCardGenerator()
    ) {
        self.model = model
        self.fallback = fallback
    }

    func generateContent(from context: VisionUnderstandingContext) async throws -> GeneratedCardContent {
        debugLog("Model availability: \(String(describing: model.availability))")

        guard model.isAvailable else {
            let message = Self.unavailableMessage(for: model.availability)
            debugLog("\(message) Falling back to MockCardGenerator content.")
            return try await fallback.generateContent(from: context)
        }

        let prompt = Self.contentPrompt(for: context)
        debugLog("Content prompt:\n\(prompt)")

        let session = LanguageModelSession(
            model: model,
            instructions: Self.contentInstructions
        )

        do {
            let response = try await session.respond(
                to: prompt,
                generating: AppleFoundationGeneratedCardContent.self,
                options: Self.generationOptions
            )
            let content = response.content.generatedContent(context: context)
            debugLog("Generated content: summary=\(content.summary), planTitle=\(content.planTitle)")
            return content
        } catch {
            debugLog("Foundation Models content generation failed: \(type(of: error)): \(String(describing: error))")
            throw error
        }
    }

    func generateCard(from context: VisionUnderstandingContext) async throws -> ActionCard {
        let generatedCard = try await generateStructuredCard(from: context)
        return try actionCard(from: generatedCard, context: context)
    }

    func streamCard(from context: VisionUnderstandingContext) -> AsyncThrowingStream<CardGenerationEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    debugLog("Model availability: \(String(describing: model.availability))")

                    guard model.isAvailable else {
                        let message = Self.unavailableMessage(for: model.availability)
                        debugLog(message)
                        throw ServiceError.unavailable(message)
                    }

                    let prompt = Self.prompt(for: context)
                    debugLog("Streaming prompt:\n\(prompt)")

                    let session = LanguageModelSession(
                        model: model,
                        instructions: Self.instructions
                    )

                    var latestDraft: AppleFoundationGeneratedActionCard.PartiallyGenerated?
                    let stream = session.streamResponse(
                        to: prompt,
                        generating: AppleFoundationGeneratedActionCard.self,
                        options: Self.generationOptions
                    )

                    for try await partialResponse in stream {
                        latestDraft = partialResponse.content
                        continuation.yield(.partial(partialResponse.content.generationPartial))
                    }

                    guard let latestDraft else {
                        throw ServiceError.invalidGeneratedCard
                    }

                    let metadata = CardMetadata(
                        sourceImage: context.sourceImage,
                        confidence: context.confidence,
                        confidenceScore: context.confidenceScore
                    )
                    let actionCard = try await MainActor.run {
                        try latestDraft.actionCard(metadata: metadata, context: context)
                    }
                    continuation.yield(.completed(actionCard))
                    continuation.finish()
                } catch {
                    debugLog("Foundation Models stream failed: \(type(of: error)): \(String(describing: error))")
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func generateStructuredCard(from context: VisionUnderstandingContext) async throws -> AppleFoundationGeneratedActionCard {
        debugLog("Model availability: \(String(describing: model.availability))")

        guard model.isAvailable else {
            let message = Self.unavailableMessage(for: model.availability)
            debugLog(message)
            throw ServiceError.unavailable(message)
        }

        let prompt = Self.prompt(for: context)
        debugLog("Prompt:\n\(prompt)")

        let session = LanguageModelSession(
            model: model,
            instructions: Self.instructions
        )

        let generatedCard: AppleFoundationGeneratedActionCard
        do {
            let response = try await session.respond(
                to: prompt,
                generating: AppleFoundationGeneratedActionCard.self,
                options: Self.generationOptions
            )
            generatedCard = response.content
            debugLog("Generated structured content: \(generatedCard.debugSummary)")
        } catch {
            debugLog("Foundation Models response failed: \(type(of: error)): \(String(describing: error))")
            throw error
        }

        return generatedCard
    }

    private func actionCard(
        from generatedCard: AppleFoundationGeneratedActionCard,
        context: VisionUnderstandingContext
    ) throws -> ActionCard {
        do {
            let actionCard = try generatedCard.actionCard(
                metadata: CardMetadata(
                    sourceImage: context.sourceImage,
                    confidence: context.confidence,
                    confidenceScore: context.confidenceScore
                ),
                context: context
            )
            debugLog("Mapped generated content to ActionCard: type=\(actionCard.type.rawValue), title=\(actionCard.title)")
            return actionCard
        } catch {
            debugLog("Generated content could not be mapped to ActionCard: \(type(of: error)): \(String(describing: error))")
            throw error
        }
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[CaptureFlow][AppleFoundationCardGenerator] \(message)")
        #endif
    }

    private static let instructions = """
    You turn local image analysis context into one editable CaptureFlow ActionCard.
    Use only facts present in the provided context. Do not invent people, dates,
    locations, prices, companies, or contact details. If a value is unknown, leave
    the matching optional field empty.

    Prefer evidence over interpretation. Avoid subjective judgments such as fit,
    importance, urgency, intent, or likelihood unless those words appear in the
    detected text. Notes should preserve useful context from the image, not tell
    the user what to do. Write notes as 1-3 concise sentences.
    """

    private static let contentInstructions = """
    You turn local image understanding context into GeneratedCardContent for CaptureFlow.
    Use only facts present in the provided context. Do not invent people, dates,
    locations, prices, companies, stores, URLs, contact details, salary, deadlines,
    or attendees. If a useful value is not present, put that gap in missingInfo.

    keyDetails must be grounded in entities. planSteps must be grounded in
    possibleActions and recommendedPlanTitle. draftOutput must be grounded in
    draftIntent. sourceReasoning must be grounded in evidence. Keep the personal
    note as a placeholder, not a generated opinion.
    """

    private static let generationOptions = GenerationOptions(
        sampling: .greedy,
        temperature: 0.2,
        maximumResponseTokens: 1200
    )

    private static func prompt(for context: VisionUnderstandingContext) -> String {
        """
        Build a \(context.resolvedCardType.rawValue) card from this local image understanding context.
        Use ISO 8601 date-time strings with timezone when date fields are present.
        Prefer Asia/Taipei timezone if the context does not include a timezone.
        Fill notes with card-specific context:
        - Reminder: what the reminder is about, plus explicit date, time, and place evidence.
        - Calendar: agenda, venue, attendees, or event details visible in the image.
        - Note: summarize the captured text and keep concrete key points.
        - Shopping: product, merchant, price, offer, and visible purchase context.
        - Job: role, company, requirements, contact, location, compensation, and application details.
        For job cards, only fill detail when the image explicitly includes an application
        instruction, contact method, deadline, interview detail, or other specific job detail.
        Only fill dueDate when the image explicitly includes a relevant date.

        Requested card type: \(context.requestedCardType.rawValue)
        Resolved card type: \(context.resolvedCardType.rawValue)
        Scene title: \(context.sceneTitle)
        Scene summary: \(context.sceneSummary)
        User intent guess: \(context.userIntentGuess)
        Visible text: \(context.visibleText.joined(separator: " | "))
        Visual objects: \(context.visualObjects.joined(separator: " | "))
        Layout description: \(context.layoutDescription)
        Entities: \(context.entities.promptLines)
        Possible actions: \(context.possibleActions.promptLines)
        Constraints: \(context.constraints.joined(separator: " | "))
        Missing info: \(context.missingInfo.joined(separator: " | "))
        Recommended plan title: \(context.recommendedPlanTitle)
        Draft intent: \(context.draftIntent)
        Confidence score: \(context.confidenceScore)
        Evidence: \(context.evidence.joined(separator: " | "))
        """
    }

    private static func contentPrompt(for context: VisionUnderstandingContext) -> String {
        """
        Build GeneratedCardContent from this local image understanding context.
        The selected card type is represented by requestedCardType when it is not auto.

        Required output shape:
        - summary: concise image-grounded summary.
        - planTitle: use or refine recommendedPlanTitle without adding new facts.
        - planSteps: derive from possibleActions and recommendedPlanTitle.
        - keyDetails: derive from entities only.
        - recommendedActions: derive from possibleActions only.
        - draftOutput: derive from draftIntent only.
        - missingInfo: include only missing or uncertain info from missingInfo and constraints.
        - sourceReasoning: derive from evidence only.
        - personalNotePlaceholder: placeholder text only.

        Requested card type: \(context.requestedCardType.rawValue)
        Resolved card type: \(context.resolvedCardType.rawValue)
        Scene title: \(context.sceneTitle)
        Scene summary: \(context.sceneSummary)
        User intent guess: \(context.userIntentGuess)
        Visible text: \(context.visibleText.joined(separator: " | "))
        Visual objects: \(context.visualObjects.joined(separator: " | "))
        Layout description: \(context.layoutDescription)
        Entities: \(context.entities.promptLines)
        Possible actions: \(context.possibleActions.promptLines)
        Constraints: \(context.constraints.joined(separator: " | "))
        Missing info: \(context.missingInfo.joined(separator: " | "))
        Recommended plan title: \(context.recommendedPlanTitle)
        Draft intent: \(context.draftIntent)
        Confidence score: \(context.confidenceScore)
        Evidence: \(context.evidence.joined(separator: " | "))
        """
    }

    private static func unavailableMessage(
        for availability: SystemLanguageModel.Availability
    ) -> String {
        switch availability {
        case .available:
            "Apple Foundation Models is available."
        case .unavailable(let reason):
            "Apple Foundation Models is unavailable: \(String(describing: reason))"
        }
    }
}

@available(iOS 26.0, *)
@Generable
private struct AppleFoundationGeneratedCardContent {
    @Guide(description: "Concise summary grounded in sceneSummary, visibleText, entities, and evidence only.")
    var summary: String

    @Guide(description: "Plan title grounded in recommendedPlanTitle and requested/resolved card type only.")
    var planTitle: String

    @Guide(description: "Plan steps derived from possibleActions and recommendedPlanTitle.", .maximumCount(6))
    var planSteps: [AppleFoundationGeneratedPlanStep]

    @Guide(description: "Key details derived from entities only.", .maximumCount(12))
    var keyDetails: [AppleFoundationGeneratedField]

    @Guide(description: "Recommended actions derived from possibleActions only.", .maximumCount(6))
    var recommendedActions: [AppleFoundationGeneratedAction]

    @Guide(description: "Draft output derived from draftIntent only.")
    var draftOutput: AppleFoundationGeneratedDraft

    @Guide(description: "Information gaps from missingInfo and constraints only.", .maximumCount(8))
    var missingInfo: [String]

    @Guide(description: "Reasoning bullets derived from evidence only.", .maximumCount(8))
    var sourceReasoning: [String]

    @Guide(description: "A placeholder for the user's own note. Do not write a personal note.")
    var personalNotePlaceholder: String

    func generatedContent(context: VisionUnderstandingContext) -> GeneratedCardContent {
        let fallback = GeneratedCardContent.fallback(from: context)

        return GeneratedCardContent(
            summary: summary.nonEmpty(or: context.sceneSummary),
            planTitle: planTitle.nonEmpty(or: context.recommendedPlanTitle),
            planSteps: context.generatedPlanSteps,
            keyDetails: context.generatedKeyDetails,
            recommendedActions: context.generatedRecommendedActions,
            draftOutput: GeneratedDraft(
                type: context.generatedDraftType,
                title: draftOutput.title.nonEmpty(or: context.recommendedPlanTitle),
                body: draftOutput.body.nonEmpty(or: context.draftIntent)
            ),
            missingInfo: context.generatedMissingInfo.nonEmpty(or: fallback.missingInfo),
            sourceReasoning: context.evidence.nonEmpty(or: fallback.sourceReasoning),
            personalNotePlaceholder: personalNotePlaceholder.nonEmpty(or: fallback.personalNotePlaceholder)
        )
    }
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
private struct AppleFoundationGeneratedDraft {
    var type: AppleFoundationGeneratedDraftType
    var title: String
    var body: String
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
@Generable
private enum AppleFoundationGeneratedDraftType {
    case reminder
    case calendar
    case note
    case shopping
    case job
    case summary
    case custom
}

@available(iOS 26.0, *)
@Generable
private struct AppleFoundationGeneratedActionCard {
    @Guide(description: "The exact card type to create.")
    var cardType: AppleFoundationGeneratedCardType

    @Guide(description: "Short user-facing title.")
    var title: String

    @Guide(description: "1-3 concise sentences of useful context grounded in the detected image text. Do not invent advice or subjective judgments.")
    var notes: String?

    @Guide(description: "ISO 8601 date-time for an explicit relevant date in the context, or nil.")
    var dueDate: String?

    @Guide(description: "ISO 8601 calendar start date-time, or nil.")
    var startDate: String?

    @Guide(description: "ISO 8601 calendar end date-time, or nil.")
    var endDate: String?

    @Guide(description: "Detected or inferred location from the context only.")
    var location: String?

    @Guide(description: "Product or offer name for shopping cards.")
    var productName: String?

    @Guide(description: "Detected price string for shopping cards.")
    var price: String?

    @Guide(description: "Detected merchant or store name.")
    var merchant: String?

    @Guide(description: "Detected shopping offer or discount.")
    var offer: String?

    @Guide(description: "Company name for job cards.")
    var company: String?

    @Guide(description: "Role title for job cards.")
    var role: String?

    @Guide(description: "Skills from the job context.", .maximumCount(8))
    var skills: [String]

    @Guide(description: "Contact detail from the context.")
    var contact: String?

    @Guide(description: "Explicit detail, instruction, or requirement from the image text, otherwise nil.")
    var detail: String?

    @Guide(description: "Summary for note cards.")
    var summary: String?

    @Guide(description: "Important note bullets.", .maximumCount(6))
    var bullets: [String]

    @Guide(description: "Concrete list items from the image text.", .maximumCount(6))
    var items: [String]

    var debugSummary: String {
        [
            "cardType=\(cardType)",
            "title=\(title)",
            "notes=\(notes ?? "nil")",
            "dueDate=\(dueDate ?? "nil")",
            "startDate=\(startDate ?? "nil")",
            "endDate=\(endDate ?? "nil")",
            "location=\(location ?? "nil")",
            "productName=\(productName ?? "nil")",
            "price=\(price ?? "nil")",
            "merchant=\(merchant ?? "nil")",
            "offer=\(offer ?? "nil")",
            "company=\(company ?? "nil")",
            "role=\(role ?? "nil")",
            "skills=\(skills)",
            "contact=\(contact ?? "nil")",
            "detail=\(detail ?? "nil")",
            "summary=\(summary ?? "nil")",
            "bullets=\(bullets)",
            "items=\(items)"
        ].joined(separator: ", ")
    }

    func actionCard(
        metadata: CardMetadata,
        context: VisionUnderstandingContext
    ) throws -> ActionCard {
        switch resolvedType(context: context) {
        case .auto:
            throw ServiceError.unsupportedCardType(.auto)
        case .reminder:
            return .reminder(
                ReminderCard(
                    metadata: metadata,
                    title: title.nonEmpty(or: context.fallbackTitle),
                    notes: notes.nonEmpty(or: context.contextNotes(for: .reminder)),
                    dueDate: Date.captureFlowDate(from: dueDate),
                    location: location.nonEmpty,
                    priority: .none
                )
            )
        case .calendar:
            guard let startDate = Date.captureFlowDate(from: startDate) else {
                throw ServiceError.invalidGeneratedCard
            }

            let endDate = Date.captureFlowDate(from: endDate)
                ?? startDate.addingTimeInterval(60 * 60)

            return .calendar(
                CalendarCard(
                    metadata: metadata,
                    title: title.nonEmpty(or: context.fallbackTitle),
                    startDate: startDate,
                    endDate: max(endDate, startDate.addingTimeInterval(30 * 60)),
                    location: location.nonEmpty,
                    notes: notes.nonEmpty(or: context.contextNotes(for: .calendar))
                )
            )
        case .note:
            return .note(
                NoteCard(
                    metadata: metadata,
                    title: title.nonEmpty(or: context.fallbackTitle),
                    summary: summary.nonEmpty(or: notes.nonEmpty(or: context.contextNotes(for: .note))),
                    bullets: bullets.nonEmpty(or: context.visibleText),
                    items: items.nonEmpty(or: [])
                )
            )
        case .shopping:
            return .shopping(
                ShoppingCard(
                    metadata: metadata,
                    productName: productName.nonEmpty(or: title.nonEmpty(or: context.fallbackTitle)),
                    price: price.nonEmpty ?? context.entityValues(for: .price).first,
                    merchant: merchant.nonEmpty,
                    offer: offer.nonEmpty,
                    date: Date.captureFlowDate(from: dueDate),
                    notes: notes.nonEmpty(or: context.contextNotes(for: .shopping))
                )
            )
        case .job:
            return .job(
                JobCard(
                    metadata: metadata,
                    company: company.nonEmpty(or: context.entityValues(for: .company).first ?? "Unknown company"),
                    role: role.nonEmpty(or: title.nonEmpty(or: "Job opportunity")),
                    skills: skills.nonEmpty(or: context.entityValues(for: .skill)),
                    contact: contact.nonEmpty,
                    detail: detail.nonEmpty(or: ""),
                    date: Date.captureFlowDate(from: dueDate),
                    notes: notes.nonEmpty(or: context.contextNotes(for: .job))
                )
            )
        }
    }

    private func resolvedType(context: VisionUnderstandingContext) -> CardType {
        if context.resolvedCardType == .auto {
            return cardType.cardType
        }

        return context.resolvedCardType
    }
}

@available(iOS 26.0, *)
private extension AppleFoundationGeneratedActionCard.PartiallyGenerated {
    var generationPartial: CardGenerationPartial {
        let fallbackTitle = [
            title,
            productName,
            role,
            company
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }

        let fallbackSummary = [
            summary,
            notes,
            detail,
            offer
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }

        return CardGenerationPartial(
            title: fallbackTitle,
            summary: fallbackSummary
        )
    }

    @MainActor
    func actionCard(
        metadata: CardMetadata,
        context: VisionUnderstandingContext
    ) throws -> ActionCard {
        switch resolvedType(context: context) {
        case .auto:
            throw ServiceError.unsupportedCardType(.auto)
        case .reminder:
            return .reminder(
                ReminderCard(
                    metadata: metadata,
                    title: title.nonEmpty(or: context.fallbackTitle),
                    notes: notes.nonEmpty(or: context.contextNotes(for: .reminder)),
                    dueDate: Date.captureFlowDate(from: dueDate),
                    location: location.nonEmpty,
                    priority: .none
                )
            )
        case .calendar:
            guard let startDate = Date.captureFlowDate(from: startDate) else {
                throw ServiceError.invalidGeneratedCard
            }

            let endDate = Date.captureFlowDate(from: endDate)
                ?? startDate.addingTimeInterval(60 * 60)

            return .calendar(
                CalendarCard(
                    metadata: metadata,
                    title: title.nonEmpty(or: context.fallbackTitle),
                    startDate: startDate,
                    endDate: max(endDate, startDate.addingTimeInterval(30 * 60)),
                    location: location.nonEmpty,
                    notes: notes.nonEmpty(or: context.contextNotes(for: .calendar))
                )
            )
        case .note:
            return .note(
                NoteCard(
                    metadata: metadata,
                    title: title.nonEmpty(or: context.fallbackTitle),
                    summary: summary.nonEmpty(or: notes.nonEmpty(or: context.contextNotes(for: .note))),
                    bullets: arrayValue(bullets, or: context.visibleText),
                    items: arrayValue(items, or: [])
                )
            )
        case .shopping:
            return .shopping(
                ShoppingCard(
                    metadata: metadata,
                    productName: productName.nonEmpty(or: title.nonEmpty(or: context.fallbackTitle)),
                    price: price.nonEmpty ?? context.entityValues(for: .price).first,
                    merchant: merchant.nonEmpty,
                    offer: offer.nonEmpty,
                    date: Date.captureFlowDate(from: dueDate),
                    notes: notes.nonEmpty(or: context.contextNotes(for: .shopping))
                )
            )
        case .job:
            return .job(
                JobCard(
                    metadata: metadata,
                    company: company.nonEmpty(or: context.entityValues(for: .company).first ?? "Unknown company"),
                    role: role.nonEmpty(or: title.nonEmpty(or: "Job opportunity")),
                    skills: arrayValue(skills, or: context.entityValues(for: .skill)),
                    contact: contact.nonEmpty,
                    detail: detail.nonEmpty(or: ""),
                    date: Date.captureFlowDate(from: dueDate),
                    notes: notes.nonEmpty(or: context.contextNotes(for: .job))
                )
            )
        }
    }

    private func resolvedType(context: VisionUnderstandingContext) -> CardType {
        if context.resolvedCardType == .auto {
            return cardType?.cardType ?? .note
        }

        return context.resolvedCardType
    }

    private func arrayValue(_ value: [String]?, or fallback: [String]) -> [String] {
        guard let value, !value.isEmpty else {
            return fallback
        }

        return value
    }
}

@available(iOS 26.0, *)
@Generable
private enum AppleFoundationGeneratedCardType {
    case reminder
    case calendar
    case note
    case shopping
    case job

    var cardType: CardType {
        switch self {
        case .reminder:
            .reminder
        case .calendar:
            .calendar
        case .note:
            .note
        case .shopping:
            .shopping
        case .job:
            .job
        }
    }
}

#endif

private extension VisionUnderstandingContext {
    var fallbackTitle: String {
        sceneTitle.nonEmpty(or: recommendedPlanTitle.nonEmpty(or: visibleText.first ?? "Untitled card"))
    }

    func contextNotes(for cardType: CardType) -> String {
        let lines: [String?]

        switch cardType {
        case .auto:
            lines = [
                sceneSummary.nonEmpty,
                visibleText.contextSentence(prefix: "Visible text"),
                visualObjects.contextSentence(prefix: "Visible objects")
            ]
        case .reminder:
            lines = [
                sceneSummary.nonEmpty,
                entityValues(for: .date).contextSentence(prefix: "Detected dates"),
                entityValues(for: .time).contextSentence(prefix: "Detected times"),
                entityValues(for: .location).contextSentence(prefix: "Detected locations"),
                evidence.contextSentence(prefix: "Evidence")
            ]
        case .calendar:
            lines = [
                sceneSummary.nonEmpty,
                entityValues(for: .event).contextSentence(prefix: "Events"),
                entityValues(for: .date).contextSentence(prefix: "Detected dates"),
                entityValues(for: .time).contextSentence(prefix: "Detected times"),
                entityValues(for: .location).contextSentence(prefix: "Detected locations")
            ]
        case .note:
            lines = [
                sceneSummary.nonEmpty,
                visibleText.contextSentence(prefix: "Captured text"),
                entityValues(for: .note).contextSentence(prefix: "Key points")
            ]
        case .shopping:
            lines = [
                sceneSummary.nonEmpty,
                entityValues(for: .product).contextSentence(prefix: "Products"),
                entityValues(for: .price).contextSentence(prefix: "Detected prices"),
                entityValues(for: .promotion).contextSentence(prefix: "Promotions")
            ]
        case .job:
            lines = [
                sceneSummary.nonEmpty,
                entityValues(for: .company).contextSentence(prefix: "Companies mentioned"),
                entityValues(for: .role).contextSentence(prefix: "Roles mentioned"),
                entityValues(for: .skill).contextSentence(prefix: "Skills mentioned")
            ]
        }

        return lines.compactMap { $0 }.prefix(3).joined(separator: " ")
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
    var nonEmpty: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty
        else {
            return nil
        }

        return value
    }

    func nonEmpty(or fallback: String) -> String {
        nonEmpty ?? fallback
    }
}

private extension String {
    var nonEmpty: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }

    func nonEmpty(or fallback: String) -> String {
        nonEmpty ?? fallback
    }
}

private extension [String] {
    func nonEmpty(or fallback: [String]) -> [String] {
        let values = compactMap { $0.nonEmpty }
        return values.isEmpty ? fallback : values
    }

    func contextSentence(prefix: String) -> String? {
        let values = compactMap { $0.nonEmpty }
        guard !values.isEmpty else {
            return nil
        }

        return "\(prefix): \(values.prefix(5).joined(separator: "; "))."
    }
}

private extension Date {
    static func captureFlowDate(from value: String?) -> Date? {
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
