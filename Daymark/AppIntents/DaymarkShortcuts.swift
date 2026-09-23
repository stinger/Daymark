import AppIntents

struct DaymarkShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskScheduleIntent(),
            phrases: [
                "Check my schedule with \(.applicationName)",
                "Ask \(.applicationName) about my schedule",
            ],
            shortTitle: "Ask About My Schedule",
            systemImageName: "calendar.badge.clock"
        )

        AppShortcut(
            intent: ImportEventFromImageIntent(),
            phrases: [
                "Create an event from a picture with \(.applicationName)"
            ],
            shortTitle: "Create Event from Image",
            systemImageName: "calendar.badge.plus"
        )

        if #available(iOS 27.0, *) {
            AppShortcut(
                intent: SummarizeSelectedEventsIntent(),
                phrases: [
                    "Summarize events with \(.applicationName)"
                ],
                shortTitle: "Summarize Selected Events",
                systemImageName: "text.document"
            )

            AppShortcut(
                intent: CancelCalendarEventIntent(),
                phrases: [
                    "Cancel \(\.$event) with \(.applicationName)",
                    "Cancel a demo event with \(.applicationName)"
                ],
                shortTitle: "Cancel Demo Event",
                systemImageName: "calendar.badge.minus"
            )
        }
    }
}
