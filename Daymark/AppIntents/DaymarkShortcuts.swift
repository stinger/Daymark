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
    }
}
