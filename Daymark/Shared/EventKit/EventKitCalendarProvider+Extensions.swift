import EventKit
import OSLog

extension EventKitCalendarProvider: DemoEventStore {
    private static let demoLogger = Logger.daymark(category: "DemoSchedule")

    func saveDemoEvents(_ events: [DemoEventDefinition]) throws {
        guard let calendar = eventStore.defaultCalendarForNewEvents else {
            throw EventKitCalendarProviderError.missingDefaultCalendar
        }
        Self.demoLogger.info(
            "Saving \(events.count) demo events to calendarID=\(calendar.calendarIdentifier, privacy: .public) calendarTitle=\(calendar.title, privacy: .public)"
        )

        for definition in events {
            let event = EKEvent(eventStore: eventStore)
            event.calendar = calendar
            event.title = definition.title
            event.startDate = definition.start
            event.endDate = definition.end
            event.location = definition.location
            event.url = definition.ownershipURL
            event.notes = "Created by Daymark for the workshop demo."
            try eventStore.save(event, span: .thisEvent, commit: false)
        }
        try eventStore.commit()
    }

    func removeEvents(withIDs ids: Set<String>) throws {
        for id in ids {
            guard
                let event = eventStore.event(withIdentifier: id)
                    ?? eventStore.calendarItem(withIdentifier: id) as? EKEvent
            else {
                continue
            }
            try eventStore.remove(event, span: .thisEvent, commit: false)
        }
        try eventStore.commit()
    }
}
