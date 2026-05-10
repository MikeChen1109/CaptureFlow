import SwiftUI

struct CardTypePickerView: View {
    @Binding var selectedCardType: CardType

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CFSpacing.small) {
                ForEach(CardType.allCases) { cardType in
                    CFPillButton(
                        cardType.displayName,
                        systemImage: systemImage(for: cardType),
                        isSelected: selectedCardType == cardType
                    ) {
                        selectedCardType = cardType
                    }
                }
            }
            .padding(.horizontal, CFSpacing.large)
        }
        .padding(.horizontal, -CFSpacing.large)
    }

    private func systemImage(for cardType: CardType) -> String {
        switch cardType {
        case .auto:
            "sparkles"
        case .reminder:
            "checklist"
        case .calendar:
            "calendar"
        case .note:
            "note.text"
        case .shopping:
            "cart"
        case .job:
            "briefcase"
        }
    }
}
