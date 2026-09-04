import EventKit
import Foundation
import SchedulerKit

actor EventKitCalendarProvider: CalendarEventProvider, CalendarAccessProviding {
    let eventStore = EKEventStore()

    func authorizationState() -> CalendarAuthorizationState {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined:
            .notDetermined
        case .restricted:
            .restricted
        case .denied:
            .denied
        case .writeOnly:
            .writeOnly
        case .fullAccess, .authorized:
            .fullAccess
        @unknown default:
            .denied
        }
    }

    func requestFullAccess() async throws -> Bool {
        try await eventStore.requestFullAccessToEvents()
    }

    func availableCalendars() -> [CalendarDescriptor] {
        eventStore.calendars(for: .event)
            .filter { $0.type != .birthday }
            .map { CalendarDescriptor(id: $0.calendarIdentifier, title: $0.title) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    func events(in interval: DateInterval) async throws -> [CalendarEvent] {
        guard authorizationState() == .fullAccess else {
            throw CalendarEventProviderError.accessRequired
        }

        let predicate = eventStore.predicateForEvents(
            withStart: interval.start,
            end: interval.end,
            calendars: nil
        )
        return eventStore.events(matching: predicate).map(translate)
    }

    private func translate(_ event: EKEvent) -> CalendarEvent {
        CalendarEvent(
            id: event.eventIdentifier ?? event.calendarItemIdentifier,
            calendarID: event.calendar.calendarIdentifier,
            title: event.title ?? "Untitled event",
            start: event.startDate,
            end: event.endDate,
            status: status(for: event),
            kind: event.calendar.type == .birthday ? .birthday : .event,
            isAllDay: event.isAllDay,
            location: event.location,
            conferencingURL: event.url
        )
    }

    private func status(for event: EKEvent) -> CalendarEventStatus {
        if event.status == .canceled {
            return .cancelled
        }
        return switch event.attendees?.first(where: \.isCurrentUser)?.participantStatus {
        case .declined:
            .declined
        case .tentative:
            .tentative
        default:
            .accepted
        }
    }
}
