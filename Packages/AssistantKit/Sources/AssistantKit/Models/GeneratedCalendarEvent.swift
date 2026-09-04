import FoundationModels

@Generable
struct GeneratedCalendarEvent {
    let id: String
    let title: String
    let start: String
    let end: String
    let location: String?
    let conferencingURL: String?
    let classifiedAsCall: Bool
}
