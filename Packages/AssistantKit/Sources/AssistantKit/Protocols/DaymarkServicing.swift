import SchedulerKit

@MainActor
public protocol DaymarkServicing {
    var availabilityDescription: String { get }
    var isAvailable: Bool { get }

    func prewarm(
        includedCalendarIDs: Set<String>,
        workingHours: WorkingHours
    )

    func answer(
        _ request: String,
        includedCalendarIDs: Set<String>,
        workingHours: WorkingHours
    ) async throws -> AssistantResponse
}
