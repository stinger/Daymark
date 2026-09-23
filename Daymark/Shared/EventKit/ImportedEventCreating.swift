import EventKit
import Foundation

struct ImportedEvent: Sendable, Equatable {
    let title: String
    let start: Date
    let end: Date
}

protocol ImportedEventCreating: Sendable {
    func createImportedEvent(
        title: String,
        start: Date,
        importID: String
    ) async throws -> ImportedEvent
}

extension EventKitCalendarProvider: ImportedEventCreating {
    func createImportedEvent(
        title: String,
        start: Date,
        importID: String
    ) throws -> ImportedEvent {
        guard authorizationState() == .fullAccess else {
            throw EventKitCalendarProviderError.fullAccessRequired
        }
        guard let calendar = eventStore.defaultCalendarForNewEvents else {
            throw EventKitCalendarProviderError.missingDefaultCalendar
        }

        let end = start.addingTimeInterval(60 * 60)
        let ownershipURL = URL(string: "daymark://ocr-import/\(importID)")!
        let interval = DateInterval(start: start.addingTimeInterval(-1), end: end)
        if let existing = eventStore.events(
            matching: eventStore.predicateForEvents(
                withStart: interval.start,
                end: interval.end,
                calendars: [calendar]
            )
        ).first(where: { $0.url == ownershipURL }) {
            return ImportedEvent(title: existing.title, start: existing.startDate, end: existing.endDate)
        }

        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.title = title
        event.startDate = start
        event.endDate = end
        event.url = ownershipURL
        event.notes = "Created by Daymark from an image."
        try eventStore.save(event, span: .thisEvent, commit: true)
        return ImportedEvent(title: title, start: start, end: end)
    }
}
