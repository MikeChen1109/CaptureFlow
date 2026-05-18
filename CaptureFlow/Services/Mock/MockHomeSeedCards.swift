import Foundation

enum MockHomeSeedCards {
    static func cards(now: Date = .now) -> [SavedInsightCard] {
        [
            reminder(
                title: "Renew Notion workspace",
                summary: "Billing notice shows the workspace renewal is due this Friday.",
                notes: "Check team seats and update billing owner before renewal.",
                offsetDays: 2,
                confidence: 0.94,
                updatedAt: now.addingTimeInterval(-600),
                status: .saved
            ),
            calendar(
                title: "Product review with design",
                summary: "Screenshot includes a design review invitation with agenda items.",
                location: "Zoom",
                startOffsetHours: 26,
                confidence: 0.9,
                updatedAt: now.addingTimeInterval(-1_800),
                status: .saved
            ),
            shopping(
                title: "Buy replacement SSD",
                summary: "Promo card shows a 2TB SSD discount ending soon.",
                productName: "2TB NVMe SSD",
                merchant: "TechMall",
                offer: "18% off through midnight",
                offsetDays: 1,
                confidence: 0.86,
                updatedAt: now.addingTimeInterval(-3_600),
                status: .saved
            ),
            note(
                title: "Q2 launch notes",
                summary: "Captured release checklist with copy, QA, and launch owner details.",
                bullets: ["Finalize release copy", "Confirm QA sign-off", "Prepare support macro"],
                confidence: 0.82,
                updatedAt: now.addingTimeInterval(-5_400),
                status: .saved
            ),
            job(
                title: "Senior iOS Engineer follow-up",
                summary: "Recruiter message includes follow-up deadline and role details.",
                company: "Northstar Labs",
                role: "Senior iOS Engineer",
                detail: "Send portfolio links and availability windows.",
                offsetDays: 3,
                confidence: 0.88,
                updatedAt: now.addingTimeInterval(-7_200),
                status: .saved
            ),
            completedReminder(
                title: "Submit travel reimbursement",
                summary: "Expense portal reminder has already been created.",
                notes: "Attach hotel receipt and taxi invoice.",
                confidence: 0.91,
                updatedAt: now.addingTimeInterval(-9_000)
            ),
            completedCalendar(
                title: "Dentist appointment",
                summary: "Calendar event has already been created from appointment details.",
                location: "Smile Clinic",
                startOffsetHours: 72,
                confidence: 0.89,
                updatedAt: now.addingTimeInterval(-10_800)
            ),
            shopping(
                title: "Compare standing desk prices",
                summary: "Product screenshot includes dimensions, merchant, and sale price.",
                productName: "Walnut standing desk",
                merchant: "Workspace Co.",
                offer: "$120 off bundle",
                offsetDays: 5,
                confidence: 0.78,
                updatedAt: now.addingTimeInterval(-12_600),
                status: .saved
            ),
            note(
                title: "Support issue summary",
                summary: "Captured conversation includes repro steps and affected account ID.",
                bullets: ["User cannot export CSV", "Started after workspace migration", "Needs backend log check"],
                confidence: 0.8,
                updatedAt: now.addingTimeInterval(-14_400),
                status: .saved
            ),
            job(
                title: "Portfolio review task",
                summary: "Screenshot lists hiring manager feedback and requested changes.",
                company: "BrightLayer",
                role: "Product Designer",
                detail: "Revise case study metrics before sending the final deck.",
                offsetDays: 4,
                confidence: 0.76,
                updatedAt: now.addingTimeInterval(-16_200),
                status: .saved
            )
        ]
    }

    private static func reminder(
        title: String,
        summary: String,
        notes: String,
        offsetDays: Int,
        confidence: Double,
        updatedAt: Date,
        status: CardStatus
    ) -> SavedInsightCard {
        let metadata = metadata(confidence: confidence, updatedAt: updatedAt, status: status)
        return savedCard(
            metadata: metadata,
            title: title,
            summary: summary,
            actionCard: .reminder(
                ReminderCard(
                    metadata: metadata,
                    title: title,
                    notes: notes,
                    dueDate: dueDate(from: updatedAt, offsetDays: offsetDays),
                    priority: .medium
                )
            )
        )
    }

    private static func completedReminder(
        title: String,
        summary: String,
        notes: String,
        confidence: Double,
        updatedAt: Date
    ) -> SavedInsightCard {
        let metadata = metadata(confidence: confidence, updatedAt: updatedAt, status: .completed)
        let externalID = "mock-reminder-\(metadata.id.uuidString)"
        return savedCard(
            metadata: metadata,
            title: title,
            summary: summary,
            actionCard: .reminder(
                ReminderCard(
                    metadata: metadata,
                    title: title,
                    notes: notes,
                    dueDate: dueDate(from: updatedAt, offsetDays: 1),
                    priority: .high,
                    reminderExternalID: externalID
                )
            ),
            reminderExternalID: externalID
        )
    }

    private static func calendar(
        title: String,
        summary: String,
        location: String,
        startOffsetHours: TimeInterval,
        confidence: Double,
        updatedAt: Date,
        status: CardStatus
    ) -> SavedInsightCard {
        let metadata = metadata(confidence: confidence, updatedAt: updatedAt, status: status)
        let startDate = updatedAt.addingTimeInterval(startOffsetHours * 3_600)
        return savedCard(
            metadata: metadata,
            title: title,
            summary: summary,
            actionCard: .calendar(
                CalendarCard(
                    metadata: metadata,
                    title: title,
                    startDate: startDate,
                    endDate: startDate.addingTimeInterval(3_600),
                    location: location,
                    notes: summary
                )
            )
        )
    }

    private static func completedCalendar(
        title: String,
        summary: String,
        location: String,
        startOffsetHours: TimeInterval,
        confidence: Double,
        updatedAt: Date
    ) -> SavedInsightCard {
        let metadata = metadata(confidence: confidence, updatedAt: updatedAt, status: .completed)
        let externalID = "mock-calendar-\(metadata.id.uuidString)"
        let startDate = updatedAt.addingTimeInterval(startOffsetHours * 3_600)
        return savedCard(
            metadata: metadata,
            title: title,
            summary: summary,
            actionCard: .calendar(
                CalendarCard(
                    metadata: metadata,
                    title: title,
                    startDate: startDate,
                    endDate: startDate.addingTimeInterval(3_600),
                    location: location,
                    notes: summary,
                    calendarExternalID: externalID
                )
            ),
            calendarExternalID: externalID
        )
    }

    private static func shopping(
        title: String,
        summary: String,
        productName: String,
        merchant: String,
        offer: String,
        offsetDays: Int,
        confidence: Double,
        updatedAt: Date,
        status: CardStatus
    ) -> SavedInsightCard {
        let metadata = metadata(confidence: confidence, updatedAt: updatedAt, status: status)
        return savedCard(
            metadata: metadata,
            title: title,
            summary: summary,
            actionCard: .shopping(
                ShoppingCard(
                    metadata: metadata,
                    productName: productName,
                    merchant: merchant,
                    offer: offer,
                    date: dueDate(from: updatedAt, offsetDays: offsetDays),
                    notes: summary
                )
            )
        )
    }

    private static func job(
        title: String,
        summary: String,
        company: String,
        role: String,
        detail: String,
        offsetDays: Int,
        confidence: Double,
        updatedAt: Date,
        status: CardStatus
    ) -> SavedInsightCard {
        let metadata = metadata(confidence: confidence, updatedAt: updatedAt, status: status)
        return savedCard(
            metadata: metadata,
            title: title,
            summary: summary,
            actionCard: .job(
                JobCard(
                    metadata: metadata,
                    company: company,
                    role: role,
                    skills: ["SwiftUI", "Product thinking"],
                    detail: detail,
                    date: dueDate(from: updatedAt, offsetDays: offsetDays),
                    notes: summary
                )
            )
        )
    }

    private static func note(
        title: String,
        summary: String,
        bullets: [String],
        confidence: Double,
        updatedAt: Date,
        status: CardStatus
    ) -> SavedInsightCard {
        let metadata = metadata(confidence: confidence, updatedAt: updatedAt, status: status)
        return savedCard(
            metadata: metadata,
            title: title,
            summary: summary,
            actionCard: .note(
                NoteCard(
                    metadata: metadata,
                    title: title,
                    summary: summary,
                    bullets: bullets
                )
            )
        )
    }

    private static func savedCard(
        metadata: CardMetadata,
        title: String,
        summary: String,
        actionCard: ActionCard,
        reminderExternalID: String? = nil,
        calendarExternalID: String? = nil
    ) -> SavedInsightCard {
        SavedInsightCard(
            metadata: metadata,
            insight: GeneratedInsightCard(
                id: metadata.id,
                title: title,
                usefulness: .useful,
                confidence: metadata.confidenceScore,
                summary: summary,
                sections: [
                    InsightSection(
                        kind: .summary,
                        title: "Summary",
                        content: summary,
                        priority: 1
                    ),
                    InsightSection(
                        kind: .suggestedActions,
                        title: "Next Step",
                        content: "Review the captured details and take the suggested action.",
                        priority: 2
                    )
                ]
            ),
            actionCard: actionCard,
            reminderExternalID: reminderExternalID,
            calendarExternalID: calendarExternalID
        )
    }

    private static func metadata(
        confidence: Double,
        updatedAt: Date,
        status: CardStatus
    ) -> CardMetadata {
        CardMetadata(
            createdAt: updatedAt.addingTimeInterval(-1_800),
            updatedAt: updatedAt,
            confidence: ConfidenceLevel.from(score: confidence),
            confidenceScore: confidence,
            status: status
        )
    }

    private static func dueDate(from date: Date, offsetDays: Int) -> Date {
        date.addingTimeInterval(TimeInterval(offsetDays) * 86_400)
    }
}
