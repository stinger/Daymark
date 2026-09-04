import Foundation

public struct AvailabilitySearchResult: Sendable, Equatable {
    public let searchedInterval: DateInterval
    public let workingInterval: DateInterval
    public let requestedDuration: TimeInterval
    public let slots: [DateInterval]

    public init(
        searchedInterval: DateInterval,
        workingInterval: DateInterval,
        requestedDuration: TimeInterval,
        slots: [DateInterval]
    ) {
        self.searchedInterval = searchedInterval
        self.workingInterval = workingInterval
        self.requestedDuration = requestedDuration
        self.slots = slots
    }
}
