import SchedulerKit
struct ScheduleConfiguration: Equatable {
    let includedCalendarIDs: Set<String>
    let workingHours: WorkingHours
}
