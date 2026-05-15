import Foundation

struct GeneratedSectionState: Identifiable, Equatable, Sendable {
    var id: UUID { section.id }
    var section: InsightSection
    var status: GeneratedSectionStatus
}

enum GeneratedSectionStatus: String, Sendable {
    case waiting
    case generating
    case completed
}

enum CardGenerationStatus: Sendable {
    case generating
    case completed
    case failed
}

struct GeneratedSectionStateMachine: Sendable {
    private(set) var sectionStates: [GeneratedSectionState]
    private(set) var generationStatus: CardGenerationStatus

    init() {
        self.sectionStates = []
        self.generationStatus = .generating
    }

    var firstWaitingSection: GeneratedSectionState? {
        sectionStates.first { $0.status == .waiting }
    }

    mutating func complete(with card: GeneratedInsightCard) {
        sectionStates = card.sections
            .sorted { $0.priority < $1.priority }
            .map {
                GeneratedSectionState(
                    section: $0,
                    status: .completed
                )
            }
        generationStatus = .completed
    }

    mutating func fail() {
        generationStatus = .failed
    }
}
