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
        case .reminder:
            return reminderContext(requestedCardType: selectedCardType, sourceImage: sourceImage)
        case .event:
            return calendarContext(requestedCardType: selectedCardType, sourceImage: sourceImage)
        case .note, .article, .document, .appScreen, .contact, .travel, .other, .unknown:
            return noteContext(requestedCardType: selectedCardType, resolvedCardType: resolvedCardType, sourceImage: sourceImage)
        case .shopping, .food, .receipt, .product, .promotion:
            return shoppingContext(requestedCardType: selectedCardType, resolvedCardType: resolvedCardType, sourceImage: sourceImage)
        case .job:
            return jobContext(requestedCardType: selectedCardType, sourceImage: sourceImage)
        }
    }

    private func shoppingContext(
        requestedCardType: CardType,
        resolvedCardType: CardType = .shopping,
        sourceImage: CardSourceImage?
    ) -> VisionUnderstandingContext {
        VisionUnderstandingContext(
            requestedCardType: requestedCardType,
            resolvedCardType: resolvedCardType,
            sourceImage: sourceImage,
            sceneTitle: "Mechanical keyboard deal",
            sceneSummary: "An orange mechanical keyboard is shown with a visible price, limited-time discount, and hot-swap switch feature.",
            userIntentGuess: "The user may want to save the deal and compare it before buying.",
            visibleText: [
                "Orange Mechanical Keyboard",
                "NT$2,490",
                "Limited time discount",
                "Hot-swap switches"
            ],
            visualObjects: [
                "orange mechanical keyboard",
                "product offer card",
                "discount label"
            ],
            layoutDescription: "The product name, price, and promotion are presented as a shopping offer.",
            entities: [
                entity(.product, label: "Product", value: "Orange Mechanical Keyboard", confidence: 0.94),
                entity(.price, label: "Price", value: "NT$2,490", confidence: 0.96),
                entity(.promotion, label: "Promotion", value: "Limited time discount", confidence: 0.9),
                entity(.note, label: "Feature", value: "Hot-swap switches", confidence: 0.88)
            ],
            possibleActions: [
                action("Save Product Details", description: "Save the product name, price, promotion, and visible feature notes.", actionType: .save),
                action("Compare Alternatives", description: "Compare this keyboard with similar mechanical keyboards before buying.", actionType: .compare),
                action("Check Promotion Deadline", description: "Find the promotion end date before setting a purchase reminder.", actionType: .reminder)
            ],
            constraints: [
                "Promotion end date is not visible.",
                "Store name cannot be confirmed from the image.",
                "Warranty details are not shown.",
                "Exact model number is missing."
            ],
            missingInfo: [
                "Store name is not visible.",
                "Warranty details are not shown.",
                "Exact model number is missing.",
                "Promotion end date is not visible."
            ],
            recommendedPlanTitle: "Buying Plan",
            confidenceScore: 0.9,
            evidence: [
                "Visible product text reads Orange Mechanical Keyboard.",
                "Visible price reads NT$2,490.",
                "A limited-time discount label is visible.",
                "Visible text mentions hot-swap switches."
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
            sceneTitle: "iOS Engineer job post",
            sceneSummary: "A Capture Labs iOS Engineer role is shown with SwiftUI, iOS, AI features, and vision-to-action workflow responsibilities.",
            userIntentGuess: "The user may want to save the role requirements and prepare an application plan.",
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
                entity(.skill, label: "Skill", value: "AI features", confidence: 0.86),
                entity(.note, label: "Responsibility", value: "Build vision-to-action workflows", confidence: 0.84)
            ],
            possibleActions: [
                action("Save Role Details", description: "Save the company, role title, visible skills, and responsibility notes.", actionType: .save),
                action("Prepare Application Plan", description: "Use the visible requirements to plan resume tailoring and application next steps.", actionType: .followUp),
                action("Copy Job Summary", description: "Copy the extracted role summary into notes or an application tracker.", actionType: .copy)
            ],
            constraints: [
                "Salary is not visible.",
                "Application contact is not visible.",
                "Work type is not visible.",
                "Application deadline is not visible."
            ],
            missingInfo: [
                "Salary range is not visible.",
                "Application contact is not shown.",
                "Remote, hybrid, or onsite work type is not visible.",
                "Application deadline is not shown."
            ],
            recommendedPlanTitle: "Application Plan",
            confidenceScore: 0.86,
            evidence: [
                "Company text reads Capture Labs.",
                "Role text reads iOS Engineer.",
                "The skill list includes SwiftUI, iOS, and AI features.",
                "Visible responsibility text mentions vision-to-action workflows."
            ]
        )
    }

    private func calendarContext(
        requestedCardType: CardType,
        resolvedCardType: CardType = .event,
        sourceImage: CardSourceImage?
    ) -> VisionUnderstandingContext {
        VisionUnderstandingContext(
            requestedCardType: requestedCardType,
            resolvedCardType: resolvedCardType,
            sourceImage: sourceImage,
            sceneTitle: "Product review sync",
            sceneSummary: "A Product Review Sync meeting is shown for 2026-06-18 from 14:00 to 15:00 at Taipei 101 Meeting Room.",
            userIntentGuess: "The user may want to create a calendar event and keep the visible meeting details.",
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
                action("Create Calendar Event", description: "Create an event using the visible title, date, time, and location.", actionType: .calendar),
                action("Save Meeting Details", description: "Save the visible meeting details as notes on the event.", actionType: .save),
                action("Check Missing Details", description: "Confirm attendees, agenda, and any meeting link before finalizing the event.", actionType: .followUp)
            ],
            constraints: [
                "Attendees are not visible.",
                "Detailed agenda is not visible.",
                "Meeting link is not visible.",
                "Floor or full address is not visible."
            ],
            missingInfo: [
                "Attendees are not visible.",
                "Detailed agenda is not shown.",
                "Meeting link is not visible.",
                "Floor or full address is not shown."
            ],
            recommendedPlanTitle: "Calendar Plan",
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
        resolvedCardType: CardType = .note,
        sourceImage: CardSourceImage?
    ) -> VisionUnderstandingContext {
        VisionUnderstandingContext(
            requestedCardType: requestedCardType,
            resolvedCardType: resolvedCardType,
            sourceImage: sourceImage,
            sceneTitle: "Launch checklist whiteboard",
            sceneSummary: "A launch checklist is shown with tasks for polishing onboarding, testing the import flow, and preparing the demo script.",
            userIntentGuess: "The user may want to turn the whiteboard into structured notes and follow-up items.",
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
                entity(.note, label: "Topic", value: "Launch checklist", confidence: 0.89),
                entity(.note, label: "Action item", value: "Polish onboarding", confidence: 0.88),
                entity(.note, label: "Action item", value: "Test import flow", confidence: 0.87),
                entity(.note, label: "Action item", value: "Prepare demo script", confidence: 0.86)
            ],
            possibleActions: [
                action("Save Action Items", description: "Save the checklist as a structured note with action items.", actionType: .save),
                action("Copy Markdown", description: "Copy the extracted checklist into Markdown.", actionType: .copy),
                action("Create Follow-Up Tasks", description: "Create follow-up tasks for checklist items that still need owners, deadlines, or priority.", actionType: .followUp)
            ],
            constraints: [
                "Owners are not visible.",
                "Deadlines are not visible.",
                "Priority order is not visible."
            ],
            missingInfo: [
                "Task owners are not visible.",
                "Deadlines are not shown.",
                "Priority order is not clear."
            ],
            recommendedPlanTitle: "Action Items",
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
            sceneSummary: "A design meetup poster is shown with the event date, time, and city: 2026-06-15 at 19:30 in Taipei.",
            userIntentGuess: "The user may want to create a reminder and confirm missing venue details before attending.",
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
                entity(.event, label: "Event", value: "Design meetup", confidence: 0.94),
                entity(.date, label: "Date", value: "2026-06-15", confidence: 0.93),
                entity(.time, label: "Time", value: "19:30", confidence: 0.91),
                entity(.location, label: "City", value: "Taipei", confidence: 0.88)
            ],
            possibleActions: [
                action("Create Reminder", description: "Create a reminder using the visible event title, date, time, and city.", actionType: .reminder),
                action("Save Event Details", description: "Save the poster details for later reference.", actionType: .save),
                action("Confirm Venue Details", description: "Check the exact venue, agenda, and attendee details before attending.", actionType: .followUp)
            ],
            constraints: [
                "Only the city is visible, not the exact venue address.",
                "Agenda details are not visible.",
                "Attendee details are not visible."
            ],
            missingInfo: [
                "Exact venue address is not visible.",
                "Agenda details are not shown.",
                "Attendee details are not visible."
            ],
            recommendedPlanTitle: "Reminder Checklist",
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
        case .unknown:
            Self.randomMockCardType()
        default:
            selectedCardType
        }
    }

    private static func randomMockCardType() -> CardType {
        [.reminder, .event, .note, .shopping, .job].randomElement() ?? .shopping
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[CaptureFlow][MockVisionAnalyzer] \(message)")
        #endif
    }
}
