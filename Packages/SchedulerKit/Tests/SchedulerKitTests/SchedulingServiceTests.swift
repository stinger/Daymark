import Foundation
import Testing

@testable import SchedulerKit
struct SchedulingServiceTests {
    @Test
    func returnsOnlyAcceptedTimedEventsFromIncludedCalendars() async throws {
        let calendar = makeCalendar()
        let now = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 21, hour: 12)))
        let accepted = makeEvent(id: "accepted", calendarID: "work", startHour: 10, calendar: calendar)
        let inputs = [
            accepted,
            makeEvent(id: "excluded", calendarID: "personal", startHour: 9, calendar: calendar),
            makeEvent(
                id: "all-day", calendarID: "work", startHour: 0, calendar: calendar, isAllDay: true),
            makeEvent(
                id: "declined", calendarID: "work", startHour: 11, calendar: calendar, status: .declined),
            makeEvent(
                id: "cancelled", calendarID: "work", startHour: 12, calendar: calendar, status: .cancelled),
            makeEvent(
                id: "birthday", calendarID: "work", startHour: 13, calendar: calendar, kind: .birthday),
            makeEvent(
                id: "reminder", calendarID: "work", startHour: 14, calendar: calendar, kind: .reminder),
        ]
        let service = SchedulingService(
            provider: InMemoryCalendarEventProvider(storedEvents: inputs),
            includedCalendarIDs: ["work"],
            clock: FixedScheduleClock(now: now),
            calendar: calendar
        )

        let result = try await service.events(on: .today)

        #expect(result == [accepted])
    }

    @Test
    func returnsUpcomingCallsInChronologicalOrder() async throws {
        let calendar = makeCalendar()
        let now = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 21, hour: 12)))
        let nextCall = makeEvent(
            id: "next-call",
            calendarID: "work",
            startHour: 13,
            calendar: calendar,
            title: "Team call"
        )
        let laterCall = makeEvent(
            id: "later-call",
            calendarID: "work",
            startHour: 14,
            calendar: calendar,
            title: "Client meeting"
        )
        let service = SchedulingService(
            provider: InMemoryCalendarEventProvider(storedEvents: [
                makeEvent(
                    id: "past-call", calendarID: "work", startHour: 11, calendar: calendar,
                    title: "Past meeting"),
                makeEvent(
                    id: "focus", calendarID: "work", startHour: 12, calendar: calendar, title: "Focus block"),
                laterCall,
                nextCall,
            ]),
            includedCalendarIDs: ["work"],
            clock: FixedScheduleClock(now: now),
            calendar: calendar
        )

        let result = try await service.events(
            in: try service.dateInterval(for: .today),
            callsOnly: true,
            firstOnly: false
        )

        #expect(result == [nextCall, laterCall])
    }

    @Test
    func returnsEarliestUpcomingCallAndExcludesPastMatches() async throws {
        let calendar = makeCalendar()
        let now = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 21, hour: 12)))
        let expected = makeEvent(
            id: "next-call",
            calendarID: "work",
            startHour: 13,
            calendar: calendar,
            title: "Team call"
        )
        let service = SchedulingService(
            provider: InMemoryCalendarEventProvider(storedEvents: [
                makeEvent(
                    id: "past-call", calendarID: "work", startHour: 11, calendar: calendar,
                    title: "Past meeting"),
                makeEvent(
                    id: "focus", calendarID: "work", startHour: 12, calendar: calendar, title: "Focus block"),
                makeEvent(
                    id: "excluded", calendarID: "personal", startHour: 12, calendar: calendar,
                    title: "Phone call"),
                makeEvent(
                    id: "later-call", calendarID: "work", startHour: 14, calendar: calendar,
                    title: "Client meeting"),
                expected,
            ]),
            includedCalendarIDs: ["work"],
            clock: FixedScheduleClock(now: now),
            calendar: calendar
        )

        let result = try await service.events(
            in: try service.dateInterval(for: .today),
            callsOnly: true,
            firstOnly: true
        )

        #expect(result == [expected])
    }

    @Test
    func rejectsEventIntervalsLongerThanSevenDays() async throws {
        let calendar = makeCalendar()
        let start = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 1)))
        let service = SchedulingService(
            provider: InMemoryCalendarEventProvider(storedEvents: []),
            includedCalendarIDs: ["work"],
            clock: FixedScheduleClock(now: start),
            calendar: calendar
        )

        await #expect(throws: SchedulingServiceError.intervalTooLarge) {
            try await service.events(
                in: DateInterval(start: start, duration: 8 * 24 * 60 * 60)
            )
        }
    }

    @Test("Authorization loss remains distinguishable from an empty calendar")
    func propagatesAuthorizationFailure() async throws {
        let calendar = makeCalendar()
        let now = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 21, hour: 12)))
        let service = SchedulingService(
            provider: InMemoryCalendarEventProvider(
                storedEvents: [],
                retrievalError: CalendarEventProviderError.accessRequired
            ),
            includedCalendarIDs: ["work"],
            clock: FixedScheduleClock(now: now),
            calendar: calendar
        )

        await #expect(throws: CalendarEventProviderError.accessRequired) {
            try await service.events(on: .today)
        }
    }

    @Test("An authorized empty calendar remains a valid empty result")
    func returnsEmptyEventsForAuthorizedEmptyCalendar() async throws {
        let calendar = makeCalendar()
        let now = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 21, hour: 12)))
        let service = SchedulingService(
            provider: InMemoryCalendarEventProvider(storedEvents: []),
            includedCalendarIDs: ["work"],
            clock: FixedScheduleClock(now: now),
            calendar: calendar
        )

        let events = try await service.events(on: .today)

        #expect(events.isEmpty)
    }

    @Test
    func buildsTodayAndTomorrowUsingInjectedLocalCalendarAndClock() throws {
        let calendar = makeCalendar()
        let now = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 21, hour: 18)))
        let service = SchedulingService(
            provider: InMemoryCalendarEventProvider(storedEvents: []),
            includedCalendarIDs: ["work"],
            clock: FixedScheduleClock(now: now),
            calendar: calendar
        )

        let today = try service.dateInterval(for: .today)
        let tomorrow = try service.dateInterval(for: .tomorrow)

        #expect(calendar.component(.hour, from: today.start) == 0)
        #expect(calendar.component(.day, from: today.start) == 21)
        #expect(calendar.component(.day, from: tomorrow.start) == 22)
        #expect(today.end == tomorrow.start)
    }

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }

    private func makeEvent(
        id: String,
        calendarID: String,
        startHour: Int,
        calendar: Calendar,
        isAllDay: Bool = false,
        status: CalendarEventStatus = .accepted,
        kind: CalendarItemKind = .event,
        title: String? = nil
    ) -> CalendarEvent {
        let start = calendar.date(from: DateComponents(year: 2026, month: 8, day: 21, hour: startHour))!
        return CalendarEvent(
            id: id,
            calendarID: calendarID,
            title: title ?? id,
            start: start,
            end: calendar.date(byAdding: .minute, value: 30, to: start)!,
            status: status,
            kind: kind,
            isAllDay: isAllDay,
            location: nil,
            conferencingURL: nil
        )
    }
}
