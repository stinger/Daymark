import AssistantKit
import SchedulerKit

@testable import Daymark

@MainActor
final class FakeScheduleAnswerer: ScheduleAnswering {
    let readiness: ScheduleAnswerReadiness
    var outcome: ScheduleAnswerOutcome
    private(set) var receivedQuestion: String?
    private(set) var prewarmedCalendarIDs: Set<String>?
    private(set) var prewarmedWorkingHours: WorkingHours?
    private(set) var prewarmCount = 0

    init(
        readiness: ScheduleAnswerReadiness = ScheduleAnswerReadiness(
            isAvailable: true,
            diagnostic: "Foundation Models is ready."
        ),
        outcome: ScheduleAnswerOutcome = .answered(
            AssistantResponse(text: "Your first opening is 9:30 AM.")
        )
    ) {
        self.readiness = readiness
        self.outcome = outcome
    }

    func prewarm(
        includedCalendarIDs: Set<String>,
        workingHours: WorkingHours
    ) {
        prewarmedCalendarIDs = includedCalendarIDs
        prewarmedWorkingHours = workingHours
        prewarmCount += 1
    }

    func answer(_ question: String) async -> ScheduleAnswerOutcome {
        receivedQuestion = question
        return outcome
    }
}
