import AssistantKit
import SchedulerKit

@testable import Daymark

@MainActor
final class FakeDaymarkService: DaymarkServicing {
    let availabilityDescription: String
    let isAvailable: Bool
    private let response: AssistantResponse
    private let error: (any Error)?
    private let onAnswer: (() async -> Void)?
    private(set) var receivedRequest: String?
    private(set) var receivedCalendarIDs: Set<String> = []
    private(set) var receivedWorkingHours: WorkingHours?
    private(set) var prewarmedCalendarIDs: Set<String>?
    private(set) var prewarmedWorkingHours: WorkingHours?

    init(
        isAvailable: Bool = true,
        availabilityDescription: String = "Foundation Models is ready.",
        response: AssistantResponse = AssistantResponse(text: "Your first opening is 9:30 AM."),
        error: (any Error)? = nil,
        onAnswer: (() async -> Void)? = nil
    ) {
        self.isAvailable = isAvailable
        self.availabilityDescription = availabilityDescription
        self.response = response
        self.error = error
        self.onAnswer = onAnswer
    }

    func prewarm(
        includedCalendarIDs: Set<String>,
        workingHours: WorkingHours
    ) {
        prewarmedCalendarIDs = includedCalendarIDs
        prewarmedWorkingHours = workingHours
    }

    func answer(
        _ request: String,
        includedCalendarIDs: Set<String>,
        workingHours: WorkingHours
    ) async throws -> AssistantResponse {
        receivedRequest = request
        receivedCalendarIDs = includedCalendarIDs
        receivedWorkingHours = workingHours
        await onAnswer?()
        if let error {
            throw error
        }
        return response
    }
}
