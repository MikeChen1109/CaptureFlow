import SwiftUI

struct InsightSectionView: View {
    let section: InsightSection
    var status: GeneratedSectionStatus = .completed

    var body: some View {
        CFCardContainer {
            VStack(alignment: .leading, spacing: CFSpacing.large) {
                GeneratedSectionHeader(
                    title: section.title,
                    systemImage: section.kind.systemImage,
                    status: status
                )

                sectionContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentTransition(.opacity)
            }
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch section.kind {
        case .checklist:
            ChecklistContent(text: section.content)
        case .tags:
            TagsContent(text: section.content)
        case .keyDetails:
            KeyValueContent(text: section.content)
        default:
            Text(section.content)
                .font(CFTypography.body)
                .foregroundStyle(section.kind.textColor)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }
}

struct GeneratedSectionHeader: View {
    let title: String
    let systemImage: String
    let status: GeneratedSectionStatus

    var body: some View {
        HStack(spacing: CFSpacing.medium) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(status.iconColor)
                .frame(width: 28, height: 28)
                .background(status.iconBackground)
                .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.small, style: .continuous))

            Text(title)
                .font(CFTypography.callout.weight(.semibold))
                .foregroundStyle(CFColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }
}

private struct ChecklistContent: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: CFSpacing.small) {
            ForEach(text.sectionLines, id: \.self) { item in
                HStack(alignment: .top, spacing: CFSpacing.medium) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(CFColors.orangeHighlight)
                        .frame(width: 22, height: 22)

                    Text(item)
                        .font(CFTypography.callout)
                        .foregroundStyle(CFColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(CFSpacing.medium)
                .background(CFColors.elevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.medium, style: .continuous))
            }
        }
    }
}

private struct TagsContent: View {
    let text: String

    var body: some View {
        FlowLayout(spacing: CFSpacing.small) {
            ForEach(text.tagValues, id: \.self) { tag in
                Text(tag)
                    .font(CFTypography.caption.weight(.semibold))
                    .foregroundStyle(CFColors.background)
                    .padding(.horizontal, CFSpacing.medium)
                    .frame(height: 28)
                    .background(CFColors.orangeHighlight)
                    .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.pill, style: .continuous))
            }
        }
    }
}

private struct KeyValueContent: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: CFSpacing.small) {
            ForEach(text.detailItems, id: \.self) { line in
                HStack(alignment: .center, spacing: CFSpacing.medium) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(CFColors.orangeHighlight)
                        .frame(width: 22, height: 22, alignment: .center)

                    Text(line)
                        .font(CFTypography.callout)
                        .foregroundStyle(CFColors.textPrimary)
                        .frame(minHeight: 22, alignment: .center)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                .padding(.horizontal, CFSpacing.medium)
                .padding(.vertical, CFSpacing.small)
                .background(CFColors.elevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: CFCornerRadius.medium, style: .continuous))
            }
        }
    }
}

private struct FlowLayout<Content: View>: View {
    var spacing: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 86), spacing: spacing, alignment: .leading)],
            alignment: .leading,
            spacing: spacing
        ) {
            content
        }
    }
}

private extension InsightSectionKind {
    var systemImage: String {
        switch self {
        case .summary:
            "sparkles"
        case .keyDetails:
            "list.bullet.rectangle"
        case .suggestedActions:
            "arrow.right.circle"
        case .checklist:
            "checkmark.circle"
        case .draft:
            "text.bubble"
        case .missingInfo:
            "questionmark.circle"
        case .warning:
            "exclamationmark.triangle"
        case .tags:
            "tag"
        case .note:
            "note.text"
        }
    }

    var textColor: Color {
        switch self {
        case .warning, .missingInfo:
            CFColors.warning
        default:
            CFColors.textPrimary
        }
    }
}

private extension GeneratedSectionStatus {
    var iconColor: Color {
        switch self {
        case .waiting:
            CFColors.textSecondary
        case .generating, .completed:
            CFColors.background
        }
    }

    var iconBackground: Color {
        switch self {
        case .waiting:
            CFColors.elevatedSurface
        case .generating:
            CFColors.primaryOrange
        case .completed:
            CFColors.success
        }
    }
}

private extension String {
    var sectionLines: [String] {
        split(whereSeparator: \.isNewline)
            .map { String($0).strippingListPrefix }
            .filter { !$0.isEmpty }
    }

    var tagValues: [String] {
        replacingOccurrences(of: "#", with: "")
            .split { $0 == "," || $0 == "\n" || $0 == "|" }
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var detailItems: [String] {
        let newlineItems = sectionLines
        guard newlineItems.count <= 1, let onlyItem = newlineItems.first else {
            return newlineItems
        }

        let splitItems = onlyItem.smartDelimitedItems
        return splitItems.count > 1 ? splitItems : newlineItems
    }

    var strippingListPrefix: String {
        var value = trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["- [ ] ", "- ", "* ", "• "] where value.hasPrefix(prefix) {
            value.removeFirst(prefix.count)
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return value
    }

    var smartDelimitedItems: [String] {
        var items: [String] = []
        var current = ""
        let characters = Array(self)

        for index in characters.indices {
            let character = characters[index]
            let previous = index > characters.startIndex ? characters[characters.index(before: index)] : nil
            let nextIndex = characters.index(after: index)
            let next = nextIndex < characters.endIndex ? characters[nextIndex] : nil

            if character.isSmartDelimiter(previous: previous, next: next) {
                let item = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !item.isEmpty {
                    items.append(item)
                }
                current = ""
            } else {
                current.append(character)
            }
        }

        let finalItem = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !finalItem.isEmpty {
            items.append(finalItem)
        }

        return items
    }
}

private extension Character {
    func isSmartDelimiter(previous: Character?, next: Character?) -> Bool {
        switch self {
        case "|", ";", "•":
            true
        case ",":
            !(previous?.isNumber == true && next?.isNumber == true)
        default:
            false
        }
    }
}
