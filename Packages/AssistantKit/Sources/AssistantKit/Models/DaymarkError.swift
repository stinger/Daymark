import Foundation

public enum DaymarkError: LocalizedError {
    case calendarAccessRequired
    case modelUnavailable(String)

    public var errorDescription: String? {
        switch self {
        case .calendarAccessRequired:
            "Open Daymark and grant full calendar access before asking about your schedule."
        case .modelUnavailable(let message):
            message
        }
    }
}
