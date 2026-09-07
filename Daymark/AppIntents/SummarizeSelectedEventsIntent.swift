import AppIntents

@available(iOS 27.0, *)
struct SummarizeSelectedEventsIntent: AppIntent {
    static let title: LocalizedStringResource = "Summarize Selected Events"
    static let description = IntentDescription("Summarize selected Daymark demo events.")
    static var supportedModes: IntentModes { .background }

    @Parameter(
        title: "Events",
        description: "The Daymark demo events to summarize"
    )
    var events: EntityCollection<CalendarEventEntity>

    static var parameterSummary: some ParameterSummary {
        Summary("Summarize \(\.$events)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetIntent {
        let selectedEvents = try await events.resolvedEntities().sorted { $0.start < $1.start }
        let responseText = Self.summary(of: selectedEvents)

        return .result(
            dialog: "\(responseText)",
            snippetIntent: ScheduleResponseSnippetIntent(
                request: "Summarize selected events",
                responseText: responseText,
                events: selectedEvents
            )
        )
    }

    static func summary(of events: [CalendarEventEntity]) -> String {
        guard let first = events.first, let last = events.last else {
            return "No events were selected."
        }

        if events.count == 1 {
            return
                "You selected one event, \(first.title), starting \(first.start.formatted(date: .abbreviated, time: .shortened))."
        }

        return
            "You selected \(events.count) events, from \(first.title) at \(first.start.formatted(date: .abbreviated, time: .shortened)) through \(last.title), ending \(last.end.formatted(date: .abbreviated, time: .shortened))."
    }
}
