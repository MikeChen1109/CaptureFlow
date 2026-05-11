import Foundation

struct MockVisionAnalyzer: VisionAnalyzing {
    func analyze(_ request: VisionAnalysisRequest) async throws -> VisionUnderstandingContext {
        debugLog(
            "Received request: selectedCardType=\(request.selectedCardType.rawValue), " +
            "imageBytes=\(request.imageData?.count ?? 0), hasSourceImage=\(request.sourceImage != nil)"
        )

        guard request.imageData != nil || request.sourceImage != nil else {
            debugLog("Cannot create context because request has no imageData and no sourceImage")
            throw ServiceError.noImageProvided
        }

        let context = context(
            for: request.selectedCardType,
            sourceImage: request.sourceImage
        )
        debugLog(
            "Created context: requested=\(context.requestedCardType.rawValue), " +
            "resolved=\(context.resolvedCardType.rawValue), scene=\(context.sceneTitle)"
        )
        return context
    }

    private func context(
        for selectedCardType: CardType,
        sourceImage: CardSourceImage?
    ) -> VisionUnderstandingContext {
        let resolvedCardType = resolvedType(for: selectedCardType)

        switch resolvedCardType {
        case .auto:
            return context(for: .shopping, sourceImage: sourceImage)
        case .reminder:
            return reminderContext(requestedCardType: selectedCardType, sourceImage: sourceImage)
        case .calendar:
            return calendarContext(requestedCardType: selectedCardType, sourceImage: sourceImage)
        case .note:
            return noteContext(requestedCardType: selectedCardType, sourceImage: sourceImage)
        case .shopping:
            return shoppingContext(requestedCardType: selectedCardType, sourceImage: sourceImage)
        case .job:
            return jobContext(requestedCardType: selectedCardType, sourceImage: sourceImage)
        }
    }

    private func shoppingContext(
        requestedCardType: CardType,
        sourceImage: CardSourceImage?
    ) -> VisionUnderstandingContext {
        VisionUnderstandingContext(
            requestedCardType: requestedCardType,
            resolvedCardType: .shopping,
            sourceImage: sourceImage,
            sceneTitle: "Keyboard discount tag",
            sceneSummary: "The image appears to show an orange mechanical keyboard offer with a visible price and a limited-time promotion.",
            userIntentGuess: "The user likely wants to save the product, compare the deal, and decide whether to buy it later.",
            visibleText: [
                "Orange Mechanical Keyboard",
                "NT$2,490",
                "Limited time discount",
                "Hot-swap switches"
            ],
            visualObjects: [
                "orange mechanical keyboard",
                "retail shelf tag",
                "discount badge",
                "product card"
            ],
            layoutDescription: "Product name is prominent near the top, the price is centered, and the discount callout sits beside the product photo.",
            entities: [
                entity(.product, label: "Product", value: "Orange Mechanical Keyboard", confidence: 0.94),
                entity(.price, label: "Price", value: "NT$2,490", confidence: 0.96),
                entity(.promotion, label: "Promotion", value: "Limited time discount", confidence: 0.9)
            ],
            possibleActions: [
                action("Create Buying Plan", description: "Save the product, price, and promotion for a later purchase decision.", actionType: .save),
                action("Compare Alternatives", description: "Compare this keyboard against other models before buying.", actionType: .compare),
                action("Set Purchase Reminder", description: "Create a reminder to check the deal before the promotion expires.", actionType: .reminder)
            ],
            constraints: [
                "Promotion end date is not visible.",
                "Store name cannot be confirmed from the image."
            ],
            missingInfo: [
                "store",
                "warranty",
                "model number"
            ],
            recommendedPlanTitle: "Buying Plan",
            draftIntent: "Track this keyboard deal, compare options, and decide whether to purchase.",
            confidenceScore: 0.9,
            evidence: [
                "Visible product text reads Orange Mechanical Keyboard.",
                "Visible price reads NT$2,490.",
                "A limited-time discount label is visible near the product offer."
            ]
        )
    }

    private func jobContext(
        requestedCardType: CardType,
        sourceImage: CardSourceImage?
    ) -> VisionUnderstandingContext {
        VisionUnderstandingContext(
            requestedCardType: requestedCardType,
            resolvedCardType: .job,
            sourceImage: sourceImage,
            sceneTitle: "iOS engineer job post",
            sceneSummary: "The image appears to be a job posting from Capture Labs for an iOS Engineer role focused on SwiftUI and AI capture features.",
            userIntentGuess: "The user likely wants to turn the posting into an application plan and preserve the role requirements.",
            visibleText: [
                "Capture Labs",
                "iOS Engineer",
                "SwiftUI, iOS, AI features",
                "Build vision-to-action workflows"
            ],
            visualObjects: [
                "job post",
                "company name",
                "role title",
                "skills list"
            ],
            layoutDescription: "Company and role are grouped at the top, followed by a compact list of skills and product responsibilities.",
            entities: [
                entity(.company, label: "Company", value: "Capture Labs", confidence: 0.94),
                entity(.role, label: "Role", value: "iOS Engineer", confidence: 0.93),
                entity(.skill, label: "Skill", value: "SwiftUI", confidence: 0.91),
                entity(.skill, label: "Skill", value: "iOS", confidence: 0.9),
                entity(.skill, label: "Skill", value: "AI features", confidence: 0.86)
            ],
            possibleActions: [
                action("Create Application Plan", description: "Save the role, company, and required skills as an application card.", actionType: .save),
                action("Follow Up on Posting", description: "Create a follow-up task to find contact details and deadline.", actionType: .followUp),
                action("Copy Job Summary", description: "Copy the extracted role summary into notes or an application tracker.", actionType: .copy)
            ],
            constraints: [
                "No explicit salary is visible.",
                "No application contact or deadline is visible."
            ],
            missingInfo: [
                "salary",
                "contact",
                "work type",
                "deadline"
            ],
            recommendedPlanTitle: "Application Plan",
            draftIntent: "Save this iOS Engineer role and prepare next steps for applying.",
            confidenceScore: 0.86,
            evidence: [
                "Company text reads Capture Labs.",
                "Role text reads iOS Engineer.",
                "The skill list includes SwiftUI, iOS, and AI features."
            ]
        )
    }

    private func calendarContext(
        requestedCardType: CardType,
        sourceImage: CardSourceImage?
    ) -> VisionUnderstandingContext {
        VisionUnderstandingContext(
            requestedCardType: requestedCardType,
            resolvedCardType: .calendar,
            sourceImage: sourceImage,
            sceneTitle: "Product review sync",
            sceneSummary: "The image appears to show a meeting agenda for a Product Review Sync scheduled on 2026-06-18 from 14:00 to 15:00.",
            userIntentGuess: "The user likely wants to create a calendar event and keep the visible meeting context.",
            visibleText: [
                "Product Review Sync",
                "2026-06-18",
                "14:00-15:00",
                "Taipei 101 Meeting Room"
            ],
            visualObjects: [
                "meeting agenda",
                "calendar date",
                "time range",
                "meeting room label"
            ],
            layoutDescription: "The event title is at the top, with date, time range, and location listed as separate agenda details.",
            entities: [
                entity(.event, label: "Event", value: "Product Review Sync", confidence: 0.95),
                entity(.date, label: "Date", value: "2026-06-18", confidence: 0.94),
                entity(.time, label: "Time", value: "14:00-15:00", confidence: 0.93),
                entity(.location, label: "Location", value: "Taipei 101 Meeting Room", confidence: 0.9)
            ],
            possibleActions: [
                action("Create Day Plan", description: "Create a calendar event from the visible date, time, and location.", actionType: .calendar),
                action("Save Meeting Notes", description: "Preserve the visible agenda details as notes on the event.", actionType: .save),
                action("Share Event Details", description: "Share the extracted meeting details with collaborators.", actionType: .share)
            ],
            constraints: [
                "Attendees are not visible.",
                "Agenda details appear short and may be incomplete."
            ],
            missingInfo: [
                "attendees",
                "agenda",
                "exact location"
            ],
            recommendedPlanTitle: "Day Plan",
            draftIntent: "Add the product review sync to the calendar with visible time and location details.",
            confidenceScore: 0.91,
            evidence: [
                "Visible event title reads Product Review Sync.",
                "Visible date reads 2026-06-18.",
                "Visible time range reads 14:00-15:00.",
                "Visible location reads Taipei 101 Meeting Room."
            ]
        )
    }

    private func noteContext(
        requestedCardType: CardType,
        sourceImage: CardSourceImage?
    ) -> VisionUnderstandingContext {
        VisionUnderstandingContext(
            requestedCardType: requestedCardType,
            resolvedCardType: .note,
            sourceImage: sourceImage,
            sceneTitle: "Launch checklist whiteboard",
            sceneSummary: "The image appears to show a whiteboard launch checklist with onboarding, import flow testing, and demo script preparation as key points.",
            userIntentGuess: "The user likely wants to capture the whiteboard into structured notes and action items.",
            visibleText: [
                "Launch checklist",
                "Polish onboarding",
                "Test import flow",
                "Prepare demo script"
            ],
            visualObjects: [
                "whiteboard",
                "sticky notes",
                "handwritten tasks",
                "checklist marks"
            ],
            layoutDescription: "A heading sits above three short checklist items, each written as a concrete task.",
            entities: [
                entity(.note, label: "Key point", value: "Launch checklist", confidence: 0.89),
                entity(.note, label: "Action item", value: "Polish onboarding", confidence: 0.88),
                entity(.note, label: "Action item", value: "Test import flow", confidence: 0.87),
                entity(.note, label: "Action item", value: "Prepare demo script", confidence: 0.86)
            ],
            possibleActions: [
                action("Save Action Items", description: "Save the checklist as a structured note with action items.", actionType: .save),
                action("Copy Markdown", description: "Copy the extracted checklist into Markdown.", actionType: .copy),
                action("Create Follow Up", description: "Create a follow-up task for unresolved checklist work.", actionType: .followUp)
            ],
            constraints: [
                "Handwritten text may omit owners and due dates.",
                "No priority order is visible."
            ],
            missingInfo: [
                "owners",
                "deadlines",
                "priority"
            ],
            recommendedPlanTitle: "Action Items",
            draftIntent: "Turn the launch checklist into a structured note and follow-up items.",
            confidenceScore: 0.82,
            evidence: [
                "The heading reads Launch checklist.",
                "Visible checklist items mention onboarding, import flow testing, and demo script preparation.",
                "The layout is a whiteboard-style list of tasks."
            ]
        )
    }

    private func reminderContext(
        requestedCardType: CardType,
        sourceImage: CardSourceImage?
    ) -> VisionUnderstandingContext {
        VisionUnderstandingContext(
            requestedCardType: requestedCardType,
            resolvedCardType: .reminder,
            sourceImage: sourceImage,
            sceneTitle: "Design meetup reminder",
            sceneSummary: "The image appears to show a meetup poster for a design event in Taipei on 2026-06-15 at 19:30.",
            userIntentGuess: "The user likely wants a reminder checklist for attending the meetup.",
            visibleText: [
                "Design meetup",
                "2026-06-15",
                "19:30",
                "Taipei"
            ],
            visualObjects: [
                "event poster",
                "date line",
                "time label",
                "location text"
            ],
            layoutDescription: "Event title is the largest text, with date, time, and city listed underneath as separate details.",
            entities: [
                entity(.event, label: "Title", value: "Design meetup", confidence: 0.94),
                entity(.date, label: "Date", value: "2026-06-15", confidence: 0.93),
                entity(.time, label: "Time", value: "19:30", confidence: 0.91),
                entity(.location, label: "Location", value: "Taipei", confidence: 0.88)
            ],
            possibleActions: [
                action("Create Checklist Reminder", description: "Create a reminder for the meetup with the visible date, time, and city.", actionType: .reminder),
                action("Save Event Poster", description: "Save the poster details for later reference.", actionType: .save),
                action("Follow Up on Details", description: "Check for final venue, agenda, and attendee details.", actionType: .followUp)
            ],
            constraints: [
                "Only the city is visible, not the venue address.",
                "No attendee or agenda details are visible."
            ],
            missingInfo: [
                "exact location",
                "agenda",
                "attendees"
            ],
            recommendedPlanTitle: "Checklist",
            draftIntent: "Create a reminder to attend the design meetup and verify missing event details.",
            confidenceScore: 0.88,
            evidence: [
                "Visible title reads Design meetup.",
                "Visible date reads 2026-06-15.",
                "Visible time reads 19:30.",
                "Visible location text reads Taipei."
            ]
        )
    }

    private func entity(
        _ type: VisionEntityType,
        label: String,
        value: String,
        confidence: Double
    ) -> VisionEntity {
        VisionEntity(type: type, label: label, value: value, confidence: confidence)
    }

    private func action(
        _ title: String,
        description: String,
        actionType: VisionActionType
    ) -> VisionActionHint {
        VisionActionHint(title: title, description: description, actionType: actionType)
    }

    private func resolvedType(for selectedCardType: CardType) -> CardType {
        switch selectedCardType {
        case .auto:
            .shopping
        default:
            selectedCardType
        }
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[CaptureFlow][MockVisionAnalyzer] \(message)")
        #endif
    }
}
