import Foundation

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
struct AppleFoundationCardGenerator: CardGenerating {
    private let model: SystemLanguageModel
    private let promptProvider: any CardGenerationPromptProviding
    private let fallbackGenerator: any CardGenerating
    
    init(
        model: SystemLanguageModel = .default,
        promptProvider: any CardGenerationPromptProviding = DefaultCardGenerationPromptProvider(),
        fallbackGenerator: any CardGenerating = MockCardGenerator()
    ) {
        self.model = model
        self.promptProvider = promptProvider
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
                    let preferences = GenerationPreferences.current()
                    let session = LanguageModelSession(
                        model: model,
                        instructions: promptProvider.contentInstructions(for: preferences)
                    )
                    
                    let response = try await session.respond(
                        to: promptProvider.contentPrompt(for: context, preferences: preferences),
                        generating: AppleFoundationGeneratedCardContent.self,
                        options: Self.generationOptions
                    )
                    let content = try response.content.insightCard(preferences: preferences)
                    let card = GeneratedActionCardFactory.makeActionCard(from: content, context: context)
                    
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
    
    private enum GenerationMode: String {
        case foundationModels = "FoundationModels"
        case fallbackMock = "Fallback(Mock)"
    }
    
    private func logGenerationMode(_ mode: GenerationMode) {
#if DEBUG
        print("[CaptureFlow][CardGenerator] Mode=\(mode.rawValue)")
#endif
    }

    private static let generationOptions = GenerationOptions(
        sampling: .greedy,
        temperature: 0.2
    )
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
    func insightCard(preferences: GenerationPreferences) throws -> GeneratedInsightCard {
        let sections = mappedSections(preferences: preferences)
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
    
    private func mappedSections(preferences: GenerationPreferences) -> [InsightSection] {
        sections
            .compactMap(\.insightSection)
            .sorted { $0.priority < $1.priority }
            .prefix(preferences.outputDetail.maximumSectionCount)
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

extension VisionUnderstandingContext {
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
