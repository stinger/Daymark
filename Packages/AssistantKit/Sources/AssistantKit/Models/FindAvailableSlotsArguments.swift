import FoundationModels

@Generable
enum AvailabilityPeriod {
    case workingDay
    case morning
    case afternoon
    case custom
}

@Generable
struct FindAvailableSlotsArguments {
    @Guide(description: "Requested local calendar date in YYYY-MM-DD format")
    let date: String

    @Guide(description: "Use morning, afternoon, or workingDay for those named periods; use custom only for explicit time bounds")
    let period: AvailabilityPeriod

    @Guide(description: "Inclusive ISO 8601 search start for a custom period; omit for morning, afternoon, and workingDay")
    let customStart: String?

    @Guide(description: "Exclusive ISO 8601 search end for a custom period; omit for morning, afternoon, and workingDay")
    let customEnd: String?

    @Guide(description: "Required slot duration in whole minutes; use 30 when omitted")
    let durationMinutes: Int

    // swift-format-ignore
    @Guide(description: "Return only the earliest opening; use true for first-available questions and false when the user asks for multiple options")
    let firstOnly: Bool
}
