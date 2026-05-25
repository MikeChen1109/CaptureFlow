import Foundation

struct CardResultCustomFieldValues {
    private let fields: [CardResultCustomField]
    private let resolver: CardResultCustomFieldValueResolver

    init(
        fields: [CardResultCustomField],
        resolver: CardResultCustomFieldValueResolver = CardResultCustomFieldValueResolver()
    ) {
        self.fields = fields
        self.resolver = resolver
    }

    var combinedDateTime: Date? {
        firstDate?.combiningTime(from: firstTime)
    }

    var firstDate: Date? {
        fields
            .filter { $0.type == .date }
            .compactMap { resolver.date(from: $0.value) }
            .first
    }

    var firstTime: Date? {
        fields
            .filter { $0.type == .time }
            .compactMap { resolver.time(from: $0.value) }
            .first
    }

    func firstValue(for type: CardResultCustomFieldType) -> String? {
        fields
            .first { $0.type == type }?
            .value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .captureFlowNonEmpty
    }

    func joinedValues(for type: CardResultCustomFieldType, separator: String = "\n") -> String {
        fields
            .filter { $0.type == type }
            .map(\.value)
            .joined(separator: separator)
    }

    func fields(excluding excludedTypes: Set<CardResultCustomFieldType>) -> [CardResultCustomField] {
        fields.filter { !excludedTypes.contains($0.type) }
    }
}
