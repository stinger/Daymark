import Foundation

public enum ScheduleDay: Sendable {
    case today
    case tomorrow
    case date(Date)
}
