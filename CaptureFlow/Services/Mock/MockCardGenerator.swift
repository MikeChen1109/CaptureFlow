import Foundation

struct MockCardGenerator: CardGenerating {
    func generateCard(from context: MockCloudVisionContext) async throws -> ActionCard {
        let metadata = CardMetadata(
            sourceImage: context.sourceImage,
            confidence: context.confidence,
            confidenceScore: context.confidenceScore
        )

        switch context.resolvedCardType {
        case .auto:
            throw ServiceError.unsupportedCardType(.auto)
        case .reminder:
            return .reminder(
                ReminderCard(
                    metadata: metadata,
                    title: "Design meetup",
                    notes: "Detected from event poster. Confirm the final agenda before attending.",
                    dueDate: Self.date(year: 2026, month: 6, day: 15, hour: 19, minute: 30),
                    location: "Taipei",
                    priority: .medium
                )
            )
        case .calendar:
            let startDate = Self.date(year: 2026, month: 6, day: 18, hour: 14, minute: 0)

            return .calendar(
                CalendarCard(
                    metadata: metadata,
                    title: "Product Review Sync",
                    startDate: startDate,
                    endDate: startDate.addingTimeInterval(60 * 60),
                    location: "Taipei 101 Meeting Room",
                    notes: "Review product decisions and follow-up items from the captured agenda."
                )
            )
        case .note:
            return .note(
                NoteCard(
                    metadata: metadata,
                    title: "Launch Checklist",
                    summary: "Whiteboard notes about the remaining work before the prototype demo.",
                    bullets: [
                        "Onboarding needs final polish",
                        "Image import flow should be tested on device",
                        "Demo script should focus on vision-to-action speed"
                    ],
                    todos: [
                        "Polish onboarding",
                        "Test import flow",
                        "Prepare demo script"
                    ]
                )
            )
        case .shopping:
            return .shopping(
                ShoppingCard(
                    metadata: metadata,
                    productName: "Orange Mechanical Keyboard",
                    price: "NT$2,490",
                    merchant: "Mock Store",
                    offer: "Limited time discount",
                    reminderDate: Self.date(year: 2026, month: 6, day: 12, hour: 10, minute: 0),
                    notes: "Compare switch options before purchasing."
                )
            )
        case .job:
            return .job(
                JobCard(
                    metadata: metadata,
                    company: "Capture Labs",
                    role: "iOS Engineer",
                    skills: ["SwiftUI", "iOS", "AI features"],
                    contact: "recruiting@capturelabs.example",
                    nextAction: "Follow up recruiter",
                    followUpDate: Self.date(year: 2026, month: 6, day: 16, hour: 9, minute: 0),
                    notes: "Role appears aligned with product-minded iOS engineering and AI capture workflows."
                )
            )
        }
    }

    private static func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int
    ) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(identifier: "Asia/Taipei")
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute

        return components.date ?? Date(timeIntervalSince1970: 0)
    }
}
