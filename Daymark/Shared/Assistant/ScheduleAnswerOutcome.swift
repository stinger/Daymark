import AssistantKit
enum ScheduleAnswerOutcome: Equatable {
    case answered(AssistantResponse)
    case calendarAccessUnavailable(CalendarAuthorizationState)
    case assistantUnavailable(String)
    case invalidQuestion
    case failed
}
