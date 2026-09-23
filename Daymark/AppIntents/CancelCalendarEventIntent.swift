import AppIntents
import OSLog

@available(iOS 27.0, *)
struct CancelCalendarEventIntent: AppIntent {
    private static let logger = Logger.daymark(category: "CancelCalendarEventIntent")

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
        Self.logger.info(
            "Cancel intent started for entityID=\(event.id, privacy: .public) title=\(event.title, privacy: .public)"
        )
        do {
            try await requestConfirmation(dialog: "Cancel \(event.title)?")
            Self.logger.info("Cancel intent confirmed for entityID=\(event.id, privacy: .public)")

            try await CalendarEventEntityQuery().cancel(event)
            Self.logger.info("Cancel intent removed event for entityID=\(event.id, privacy: .public)")

            DaymarkShortcuts.updateAppShortcutParameters()
            Self.logger.info("Cancel intent refreshed shortcut parameters")

            return .result(dialog: "Cancelled \(event.title).")
        } catch {
            Self.logger.error(
                "Cancel intent failed for entityID=\(event.id, privacy: .public) title=\(event.title, privacy: .public): \(error, privacy: .public)"
            )
            throw error
        }
    }
}
