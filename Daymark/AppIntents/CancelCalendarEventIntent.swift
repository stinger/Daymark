import AppIntents

@available(iOS 27.0, *)
struct CancelCalendarEventIntent: AppIntent {
    static let title: LocalizedStringResource = "Cancel Calendar Event"
    static let description = IntentDescription("Cancel a Daymark demo event.")
    static var supportedModes: IntentModes { .background }

    @Parameter(
        title: "Event",
        description: "The Daymark demo event to cancel",
        requestDisambiguationDialog: "Which event should I cancel?"
    )
    var event: CalendarEventEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Cancel \(\.$event)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await requestConfirmation(dialog: "Cancel \(event.title)?")
        try await CalendarEventEntityQuery().cancel(event)
        DaymarkShortcuts.updateAppShortcutParameters()
        return .result(dialog: "Cancelled \(event.title).")
    }
}
