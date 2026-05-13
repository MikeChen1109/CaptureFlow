import Foundation

struct GeneratedSectionState: Identifiable, Equatable, Sendable {
    var id: GeneratedSectionType { sectionType }
    var sectionType: GeneratedSectionType
    var status: GeneratedSectionStatus
    var content: GeneratedSectionContent?
}

enum GeneratedSectionType: String, CaseIterable, Identifiable, Sendable {
    case summary
    case plan
    case keyDetails
    case missingInfo

    var id: String { rawValue }
}

enum GeneratedSectionStatus: String, Sendable {
    case waiting
    case generating
    case completed
}

enum GeneratedSectionContent: Equatable, Sendable {
    case summary(String)
    case plan(title: String, steps: [GeneratedPlanStep])
    case keyDetails([GeneratedField])
    case missingInfo([String])
}

enum CardGenerationStatus: Sendable {
    case generating
    case completed
    case failed
}

struct GeneratedSectionStateMachine: Sendable {
    private(set) var sectionStates: [GeneratedSectionState]
    private(set) var generationStatus: CardGenerationStatus
    private(set) var sourceReasoning: [String]

    init() {
        self.sectionStates = GeneratedSectionType.allCases.map {
            GeneratedSectionState(sectionType: $0, status: .waiting, content: nil)
        }
        self.generationStatus = .generating
        self.sourceReasoning = []
    }

    var firstWaitingSection: GeneratedSectionState? {
        sectionStates.first { $0.status == .waiting }
    }

    mutating func applyPartialContent(_ partial: GeneratedContentPartial) {
        guard generationStatus != .completed else {
            return
        }

        generationStatus = .generating
        var activeSection: GeneratedSectionType?

        if let incomingSummary = normalize(partial.summary) {
            let mergedSummary = mergedStreamedText(
                current: currentSummaryText,
                incoming: incomingSummary
            )
            setSection(.summary, status: .generating, content: .summary(mergedSummary))
            activeSection = .summary
        }

        let normalizedPlanTitle = normalize(partial.planTitle)
        let normalizedPlanSteps = sanitizedPlanSteps(from: partial.planSteps)
        var planUpdate: GeneratedSectionContent?
        if normalizedPlanTitle != nil || !normalizedPlanSteps.isEmpty {
            let title = normalizedPlanTitle ?? currentPlanTitle ?? "Plan"
            let steps = !normalizedPlanSteps.isEmpty ? normalizedPlanSteps : currentPlanSteps
            planUpdate = .plan(title: title, steps: steps)
        }

        let keyDetails = sanitizedFields(from: partial.keyDetails)
        let keyDetailsUpdate: GeneratedSectionContent? = !keyDetails.isEmpty ? .keyDetails(keyDetails) : nil

        let missingInfo = sanitizedStrings(from: partial.missingInfo)
        let missingInfoUpdate: GeneratedSectionContent? = !missingInfo.isEmpty ? .missingInfo(missingInfo) : nil

        let updatesByType: [GeneratedSectionType: GeneratedSectionContent] = [
            .plan: planUpdate,
            .keyDetails: keyDetailsUpdate,
            .missingInfo: missingInfoUpdate
        ].compactMapValues { $0 }

        if let selectedType = nextSectionToUpdate(from: updatesByType),
           let content = updatesByType[selectedType] {
            setSection(selectedType, status: .generating, content: content)
            activeSection = selectedType
        } else if let generatingType = currentGeneratingSectionType {
            activeSection = generatingType
        }

        if let reasoning = sanitizedOptionalStrings(from: partial.sourceReasoning), !reasoning.isEmpty {
            sourceReasoning = reasoning
        }

        if let activeSection {
            let keepActiveGenerating = activeSection == .summary && normalize(partial.summary) != nil
            markProgress(upTo: activeSection, keepActiveGenerating: keepActiveGenerating)
        }
    }

    mutating func complete(with content: GeneratedCardContent) {
        sourceReasoning = content.sourceReasoning

        let summary = finalSummaryText(from: content.summary)
        setSection(.summary, status: .completed, content: .summary(summary))
        setSection(
            .plan,
            status: .completed,
            content: .plan(title: content.planTitle, steps: content.planSteps)
        )
        setSection(.keyDetails, status: .completed, content: .keyDetails(content.keyDetails))
        setSection(.missingInfo, status: .completed, content: .missingInfo(content.missingInfo))

        generationStatus = .completed
    }

    mutating func fail() {
        generationStatus = .failed
    }

    private var currentPlanTitle: String? {
        guard case .plan(let title, _) = sectionContent(for: .plan) else {
            return nil
        }
        return normalize(title)
    }

    private var currentSummaryText: String? {
        guard case .summary(let summary) = sectionContent(for: .summary) else {
            return nil
        }
        return normalize(summary)
    }

    private var currentPlanSteps: [GeneratedPlanStep] {
        guard case .plan(_, let steps) = sectionContent(for: .plan) else {
            return []
        }
        return steps
    }

    private var currentGeneratingSectionType: GeneratedSectionType? {
        sectionStates.first { $0.status == .generating }?.sectionType
    }

    private func sectionContent(for type: GeneratedSectionType) -> GeneratedSectionContent? {
        sectionStates.first(where: { $0.sectionType == type })?.content
    }

    private mutating func setSection(
        _ type: GeneratedSectionType,
        status: GeneratedSectionStatus,
        content: GeneratedSectionContent?
    ) {
        guard let index = sectionStates.firstIndex(where: { $0.sectionType == type }) else {
            return
        }

        sectionStates[index].status = status
        sectionStates[index].content = content
    }

    private func sanitizedPlanSteps(from value: [GeneratedPlanStep]?) -> [GeneratedPlanStep] {
        guard let value else { return [] }
        return value.filter { normalize($0.title) != nil || normalize($0.detail) != nil }
    }

    private func sanitizedFields(from value: [GeneratedField]?) -> [GeneratedField] {
        guard let value else { return [] }
        return value.filter { normalize($0.label) != nil && normalize($0.value) != nil }
    }

    private func sanitizedStrings(from value: [String]?) -> [String] {
        sanitizedOptionalStrings(from: value) ?? []
    }

    private func sanitizedOptionalStrings(from value: [String]?) -> [String]? {
        guard let value else { return nil }
        let cleaned = value.compactMap { normalize($0) }
        return cleaned.isEmpty ? [] : cleaned
    }

    private func normalize(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func mergedStreamedText(current: String?, incoming: String) -> String {
        guard let current = current else {
            return incoming
        }

        if incoming.count >= current.count, incoming.hasPrefix(current) {
            return incoming
        }

        if current.count >= incoming.count, current.hasPrefix(incoming) {
            return current
        }

        // Allow meaningful rewrite when model emits a clearly longer draft.
        if incoming.count > current.count + 12 {
            return incoming
        }

        return current
    }

    private func position(of type: GeneratedSectionType) -> Int {
        GeneratedSectionType.allCases.firstIndex(of: type) ?? 0
    }

    private func finalSummaryText(from incomingSummary: String?) -> String {
        if let incoming = normalize(incomingSummary) {
            return incoming
        }

        return currentSummaryText ?? "Summary unavailable."
    }

    private func nextSectionToUpdate(
        from updatesByType: [GeneratedSectionType: GeneratedSectionContent]
    ) -> GeneratedSectionType? {
        let orderedTypes: [GeneratedSectionType] = [.plan, .keyDetails, .missingInfo]

        if let currentlyGenerating = currentGeneratingSectionType,
           currentlyGenerating != .summary,
           updatesByType[currentlyGenerating] != nil {
            return currentlyGenerating
        }

        for type in orderedTypes {
            guard updatesByType[type] != nil else {
                continue
            }

            if sectionContent(for: type) == nil {
                return type
            }
        }

        for type in orderedTypes where updatesByType[type] != nil {
            return type
        }

        return nil
    }

    private mutating func markProgress(
        upTo active: GeneratedSectionType,
        keepActiveGenerating: Bool
    ) {
        let activePosition = position(of: active)

        for index in sectionStates.indices {
            if index < activePosition {
                sectionStates[index].status = sectionStates[index].content == nil ? .waiting : .completed
            } else if index == activePosition {
                guard sectionStates[index].content != nil else {
                    sectionStates[index].status = .generating
                    continue
                }

                sectionStates[index].status = keepActiveGenerating ? .generating : .completed
            } else if sectionStates[index].status != .completed {
                sectionStates[index].status = .waiting
            }
        }

        if let nextIndex = sectionStates.firstIndex(where: { $0.status == .waiting }) {
            sectionStates[nextIndex].status = .generating
        }
    }
}
