import Foundation

protocol MarkdownExporting {
    var markdown: String { get }
}

extension ActionCard: MarkdownExporting {
    var markdown: String {
        switch self {
        case .reminder(let card):
            card.markdown
        case .calendar(let card):
            card.markdown
        case .note(let card):
            card.markdown
        case .shopping(let card):
            card.markdown
        case .job(let card):
            card.markdown
        }
    }
}

extension ReminderCard: MarkdownExporting {
    var markdown: String {
        MarkdownBuilder(title: title)
            .line("Type", "Reminder")
            .line("Date", dueDate?.formattedForMarkdown)
            .line("Location", location)
            .line("Priority", priority.rawValue.capitalized)
            .section("Notes", notes)
            .build()
    }
}

extension CalendarCard: MarkdownExporting {
    var markdown: String {
        MarkdownBuilder(title: title)
            .line("Type", "Calendar")
            .line("Start", startDate.formattedForMarkdown)
            .line("End", endDate.formattedForMarkdown)
            .line("Location", location)
            .section("Notes", notes)
            .build()
    }
}

extension NoteCard: MarkdownExporting {
    var markdown: String {
        MarkdownBuilder(title: title)
            .line("Type", "Note")
            .section("Summary", summary)
            .list("Key Points", bullets)
            .list("Items", items)
            .build()
    }
}

extension ShoppingCard: MarkdownExporting {
    var markdown: String {
        MarkdownBuilder(title: productName)
            .line("Type", "Shopping")
            .line("Price", price)
            .line("Merchant", merchant)
            .line("Offer", offer)
            .line("Date", date?.formattedForMarkdown)
            .section("Notes", notes)
            .build()
    }
}

extension JobCard: MarkdownExporting {
    var markdown: String {
        MarkdownBuilder(title: "\(role) at \(company)")
            .line("Type", "Job")
            .line("Company", company)
            .line("Role", role)
            .list("Skills", skills)
            .line("Contact", contact)
            .line("Detail", detail)
            .line("Date", date?.formattedForMarkdown)
            .section("Notes", notes)
            .build()
    }
}

private struct MarkdownBuilder {
    private var lines: [String]

    init(title: String) {
        lines = ["# \(title.trimmedForMarkdown)"]
    }

    func line(_ label: String, _ value: String?) -> MarkdownBuilder {
        guard let value = value?.trimmedForMarkdown, !value.isEmpty else {
            return self
        }

        var copy = self
        copy.lines.append("- **\(label):** \(value)")
        return copy
    }

    func section(_ title: String, _ value: String?) -> MarkdownBuilder {
        guard let value = value?.trimmedForMarkdown, !value.isEmpty else {
            return self
        }

        var copy = self
        copy.lines.append("")
        copy.lines.append("## \(title)")
        copy.lines.append(value)
        return copy
    }

    func list(_ title: String, _ values: [String]) -> MarkdownBuilder {
        let trimmedValues = values.map(\.trimmedForMarkdown).filter { !$0.isEmpty }
        guard !trimmedValues.isEmpty else {
            return self
        }

        var copy = self
        copy.lines.append("")
        copy.lines.append("## \(title)")
        copy.lines.append(contentsOf: trimmedValues.map { "- \($0)" })
        return copy
    }

    func checklist(_ title: String, _ values: [String]) -> MarkdownBuilder {
        let trimmedValues = values.map(\.trimmedForMarkdown).filter { !$0.isEmpty }
        guard !trimmedValues.isEmpty else {
            return self
        }

        var copy = self
        copy.lines.append("")
        copy.lines.append("## \(title)")
        copy.lines.append(contentsOf: trimmedValues.map { "- [ ] \($0)" })
        return copy
    }

    func build() -> String {
        lines.joined(separator: "\n")
    }
}

private extension String {
    var trimmedForMarkdown: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension Date {
    var formattedForMarkdown: String {
        ISO8601DateFormatter.captureFlowMarkdown.string(from: self)
    }
}

private extension ISO8601DateFormatter {
    static let captureFlowMarkdown: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        return formatter
    }()
}
