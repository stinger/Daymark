import Foundation

enum EventKitCalendarProviderError: LocalizedError {
    case fullAccessRequired
    case missingDefaultCalendar

    var errorDescription: String? {
        switch self {
        case .fullAccessRequired:
            "Full calendar access is required to retrieve events."
        case .missingDefaultCalendar:
            "A default calendar is required."
        }
    }
}
