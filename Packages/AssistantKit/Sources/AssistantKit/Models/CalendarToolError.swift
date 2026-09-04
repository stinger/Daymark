import Foundation

enum CalendarToolError: LocalizedError, Equatable {
    case invalidDate

    var errorDescription: String? {
        "The model supplied a calendar date in an unsupported format."
    }
}
