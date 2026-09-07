import AppIntents

struct DaymarkShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskScheduleIntent(),
            phrases: [
                "Check my schedule with \(.applicationName)"
            ],
            shortTitle: "Ask About My Schedule",
            systemImageName: "calendar.badge.clock"
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
        }
    }
}
