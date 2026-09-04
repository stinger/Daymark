import SchedulerKit
@MainActor
protocol ScheduleAnswering {
    var readiness: ScheduleAnswerReadiness { get }

    func prewarm(
        includedCalendarIDs: Set<String>,
        workingHours: WorkingHours
    )
    func answer(_ question: String) async -> ScheduleAnswerOutcome
}
