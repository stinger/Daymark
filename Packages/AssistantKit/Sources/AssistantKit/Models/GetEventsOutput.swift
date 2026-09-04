import FoundationModels

@Generable
struct GetEventsOutput {
    let summary: String
    let events: [GeneratedCalendarEvent]
}
