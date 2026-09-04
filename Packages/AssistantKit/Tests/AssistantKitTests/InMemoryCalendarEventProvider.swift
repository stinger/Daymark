import Foundation
import SchedulerKit

struct InMemoryCalendarEventProvider: CalendarEventProvider {
    let storedEvents: [CalendarEvent]
    var retrievalError: (any Error)?

    init(storedEvents: [CalendarEvent], retrievalError: (any Error)? = nil) {
        self.storedEvents = storedEvents
        self.retrievalError = retrievalError
    }

    func events(in interval: DateInterval) async throws -> [CalendarEvent] {
        if let retrievalError {
            throw retrievalError
        }
        return storedEvents.filter { $0.start < interval.end && $0.end > interval.start }
    }
}
