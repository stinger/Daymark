import FoundationModels

@Generable
struct FindAvailableSlotsArguments {
    @Guide(description: "Inclusive ISO 8601 search start with a timezone offset; without an offset, the configured timezone is used")
    let start: String

    @Guide(description: "Exclusive ISO 8601 search end with a timezone offset; without an offset, the configured timezone is used")
    let end: String

    @Guide(description: "Required slot duration in whole minutes; use 30 when omitted")
    let durationMinutes: Int

    // swift-format-ignore
    @Guide(description: "Return only the earliest opening; use true for first-available questions and false when the user asks for multiple options")
    let firstOnly: Bool
}
