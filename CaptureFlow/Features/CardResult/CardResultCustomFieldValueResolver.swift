import Foundation

struct CardResultCustomFieldValueResolver {
    func resolvedValue(
        for type: CardResultCustomFieldType,
        textValue: String,
        dateValue: Date
    ) -> String? {
        switch type {
        case .date:
            return dateString(from: dateValue)
        case .time:
            return timeString(from: dateValue)
        case .link:
            let trimmed = trimmedNonEmpty(textValue)
            return trimmed.flatMap(normalizedLink)
        default:
            return trimmedNonEmpty(textValue)
        }
    }

    func validationMessage(for type: CardResultCustomFieldType, textValue: String) -> String? {
        switch type {
        case .date, .time:
            return nil
        case .link:
            guard let trimmed = trimmedNonEmpty(textValue) else {
                return "Enter a link to continue."
            }
            return normalizedLink(from: trimmed) == nil
                ? "Enter a valid URL (for example https://example.com)."
                : nil
        default:
            return trimmedNonEmpty(textValue) == nil ? "Enter a value to continue." : nil
        }
    }

    func date(from value: String) -> Date? {
        Self.dateFormatter.date(from: value)
    }

    func time(from value: String) -> Date? {
        Self.timeFormatter.date(from: value)
    }

    func dateString(from date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    func timeString(from date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }

    func normalizedLink(from input: String) -> String? {
        if let url = URL(string: input), url.scheme != nil, url.host != nil {
            return url.absoluteString
        }

        let withScheme = "https://\(input)"
        guard let url = URL(string: withScheme), url.host != nil else {
            return nil
        }

        return url.absoluteString
    }

    private func trimmedNonEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static let dateFormatter: DateFormatter = {
        let resolver = DateFormatter()
        resolver.locale = .autoupdatingCurrent
        resolver.dateStyle = .medium
        resolver.timeStyle = .none
        return resolver
    }()

    private static let timeFormatter: DateFormatter = {
        let resolver = DateFormatter()
        resolver.locale = .autoupdatingCurrent
        resolver.dateStyle = .none
        resolver.timeStyle = .short
        return resolver
    }()
}
