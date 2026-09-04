import Foundation
import SchedulerKit

@testable import Daymark

actor InMemoryDemoEventStore: DemoEventStore {
    private var storedEvents: [CalendarEvent]

    init(events: [CalendarEvent] = []) {
        storedEvents = events
    }

    func events(in interval: DateInterval) -> [CalendarEvent] {
        storedEvents.filter { $0.start < interval.end && $0.end > interval.start }
    }

    func saveDemoEvents(_ events: [DemoEventDefinition]) {
        storedEvents.append(
            contentsOf: events.map { definition in
                CalendarEvent(
                    id: definition.id,
                    calendarID: "demo",
                    title: definition.title,
                    start: definition.start,
                    end: definition.end,
                    status: .accepted,
                    kind: .event,
                    isAllDay: false,
                    location: definition.location,
                    conferencingURL: definition.ownershipURL
                )
            }
        )
    }

    func removeEvents(withIDs ids: Set<String>) {
        storedEvents.removeAll { ids.contains($0.id) }
    }

    func snapshot() -> [CalendarEvent] {
        storedEvents
    }
}
