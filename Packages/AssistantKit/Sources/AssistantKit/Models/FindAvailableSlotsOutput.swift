import FoundationModels

@Generable
struct FindAvailableSlotsOutput {
    let summary: String
    let slots: [GeneratedAvailabilitySlot]
}
