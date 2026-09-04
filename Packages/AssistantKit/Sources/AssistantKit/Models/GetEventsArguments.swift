import FoundationModels

@Generable
struct GetEventsArguments {
    @Guide(description: "Inclusive ISO 8601 interval start with a timezone offset; without an offset, the configured timezone is used")
    let start: String

    @Guide(description: "Exclusive ISO 8601 interval end with a timezone offset; without an offset, the configured timezone is used")
    let end: String

    @Guide(description: "True when the user asks specifically for calls or meetings")
    let callsOnly: Bool

    @Guide(description: "True when the user asks for only the first or earliest matching event")
    let firstOnly: Bool
}
