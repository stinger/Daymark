import Foundation
import SchedulerKit
import Testing

@testable import AssistantKit

struct CalendarToolsTests {
    @Test
    func getEventsRejectsInvalidDateInterval() async throws {
        let tool = makeGetEventsTool()

        await #expect(throws: CalendarToolError.invalidDate) {
            try await tool.call(
                arguments: GetEventsArguments(
                    start: "not-a-date",
                    end: "2026-08-22T00:00:00Z",
                    callsOnly: false,
                    firstOnly: false
                )
            )
        }
    }

    @Test
    func getEventsExpandsZeroLengthModelInterval() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Sofia"))
        let formatter = ISO8601DateFormatter()
        let eventStart = try #require(formatter.date(from: "2026-09-19T10:00:00+03:00"))
        let service = SchedulingService(
            provider: InMemoryCalendarEventProvider(storedEvents: [
                event(id: "morning", title: "Morning standup", start: eventStart)
            ]),
            includedCalendarIDs: ["work"],
            clock: FixedScheduleClock(now: eventStart.addingTimeInterval(-60 * 60)),
            calendar: calendar
        )
        let tool = GetEventsTool(schedulingService: service, calendar: calendar)

        let output = try await tool.call(
            arguments: GetEventsArguments(
                start: "2026-09-19T09:00:00+03:00",
                end: "2026-09-19T09:00:00+03:00",
                callsOnly: false,
                firstOnly: false
            )
        )

        #expect(output.events.first?.title == "Morning standup")
    }

    @Test
    func getEventsTranslatesDomainEventToGeneratedOutputAndPresentationItem() async throws {
        let formatter = ISO8601DateFormatter()
        let start = try #require(formatter.date(from: "2026-08-21T13:00:00Z"))
        let event = event(id: "next", title: "Team meeting", start: start)
        let service = SchedulingService(
            provider: InMemoryCalendarEventProvider(storedEvents: [event]),
            includedCalendarIDs: ["work"],
            clock: FixedScheduleClock(now: start.addingTimeInterval(-60 * 60)),
            calendar: utcCalendar()
        )
        let resultStore = AssistantToolResultStore()
        let tool = GetEventsTool(
            schedulingService: service,
            resultStore: resultStore,
            calendar: utcCalendar()
        )

        let output = try await tool.call(
            arguments: GetEventsArguments(
                start: "2026-08-21T00:00:00",
                end: "2026-08-22T00:00:00",
                callsOnly: false,
                firstOnly: false
            )
        )

        #expect(output.events.first?.id == "event-1")
        #expect(output.events.first?.title == event.title)
        #expect(output.events.first?.start == "2026-08-21T13:00:00Z")
        #expect(output.events.first?.end == "2026-08-21T13:30:00Z")
        #expect(output.events.first?.classifiedAsCall == true)
        let item = try #require(await resultStore.recordedItems().first)
        guard case .event(let recordedEvent) = item else {
            Issue.record("Expected a recorded calendar event")
            return
        }
        #expect(recordedEvent == event)
    }

    @Test
    func getEventsInterpretsTimestampsWithoutOffsetsInTheConfiguredTimeZone() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Sofia"))
        let formatter = ISO8601DateFormatter()
        let eventStart = try #require(formatter.date(from: "2026-09-04T12:00:00+03:00"))
        let service = SchedulingService(
            provider: InMemoryCalendarEventProvider(storedEvents: [
                event(id: "local", title: "Local event", start: eventStart)
            ]),
            includedCalendarIDs: ["work"],
            clock: FixedScheduleClock(now: eventStart.addingTimeInterval(-60 * 60)),
            calendar: calendar
        )
        let tool = GetEventsTool(
            schedulingService: service,
            calendar: calendar
        )

        let output = try await tool.call(
            arguments: GetEventsArguments(
                start: "2026-09-04T11:00:00",
                end: "2026-09-04T13:00:00",
                callsOnly: false,
                firstOnly: false
            )
        )

        #expect(output.events.first?.title == "Local event")
        #expect(output.events.first?.start == "2026-09-04T12:00:00+03:00")
    }

    @Test
    func getEventsReturnsTimesInTheConfiguredLocalTimeZone() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Sofia"))
        let formatter = ISO8601DateFormatter()
        let eventStart = try #require(formatter.date(from: "2026-08-22T06:00:00Z"))
        let service = SchedulingService(
            provider: InMemoryCalendarEventProvider(storedEvents: [
                event(id: "first", title: "First event", start: eventStart)
            ]),
            includedCalendarIDs: ["work"],
            clock: FixedScheduleClock(now: eventStart.addingTimeInterval(-60 * 60)),
            calendar: calendar
        )
        let tool = GetEventsTool(
            schedulingService: service,
            calendar: calendar
        )

        let output = try await tool.call(
            arguments: GetEventsArguments(
                start: "2026-08-22T00:00:00",
                end: "2026-08-23T00:00:00",
                callsOnly: false,
                firstOnly: false
            )
        )

        #expect(output.events.first?.start == "2026-08-22T09:00:00+03:00")
        #expect(output.summary.contains("Europe/Sofia"))
    }

    @Test
    func availabilityToolQueriesAndReturnsTimesInTheConfiguredLocalCalendar() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Sofia"))
        let now = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 12)))
        let service = SchedulingService(
            provider: InMemoryCalendarEventProvider(storedEvents: []),
            includedCalendarIDs: ["work"],
            workingHours: WorkingHours(startHour: 9, endHour: 10),
            clock: FixedScheduleClock(now: now),
            calendar: calendar
        )
        let resultStore = AssistantToolResultStore()
        let tool = FindAvailableSlotsTool(
            schedulingService: service,
            resultStore: resultStore,
            calendar: calendar
        )

        let output = try await tool.call(
            arguments: FindAvailableSlotsArguments(
                date: "2026-08-21",
                period: .custom,
                customStart: "2026-08-21T09:30:00",
                customEnd: "2026-08-21T10:00:00",
                durationMinutes: 30,
                firstOnly: true
            )
        )

        #expect(output.summary.contains("earliest exact 30-minute opening"))
        #expect(output.slots.count == 1)
        #expect(output.slots.first?.start == "2026-08-21T09:30:00+03:00")
        #expect(output.slots.first?.end == "2026-08-21T10:00:00+03:00")
        let item = try #require(await resultStore.recordedItems().first)
        guard case .availabilitySlot(let interval) = item else {
            Issue.record("Expected a recorded availability slot")
            return
        }
        #expect(interval.start == now.addingTimeInterval(21.5 * 60 * 60))
        #expect(interval.duration == 30 * 60)
    }

    @Test
    func availabilityToolResolvesMorningToNoon() async throws {
        var calendar = utcCalendar()
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Sofia"))
        let service = SchedulingService(
            provider: InMemoryCalendarEventProvider(storedEvents: []),
            includedCalendarIDs: ["work"],
            workingHours: WorkingHours(startHour: 9, endHour: 17),
            clock: FixedScheduleClock(now: .distantPast),
            calendar: calendar
        )
        let tool = FindAvailableSlotsTool(
            schedulingService: service,
            calendar: calendar
        )

        let output = try await tool.call(
            arguments: FindAvailableSlotsArguments(
                date: "2026-09-16",
                period: .morning,
                customStart: nil,
                customEnd: nil,
                durationMinutes: 30,
                firstOnly: false
            )
        )

        #expect(output.slots.first?.start == "2026-09-16T09:00:00+03:00")
        #expect(output.slots.last?.end == "2026-09-16T12:00:00+03:00")
        #expect(output.slots.count == 6)
    }

    @Test
    func getEventsHonorsModelSuppliedOffset() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Sofia"))
        let formatter = ISO8601DateFormatter()
        let eventStart = try #require(formatter.date(from: "2026-09-04T10:00:00+02:00"))
        let service = SchedulingService(
            provider: InMemoryCalendarEventProvider(storedEvents: [
                event(id: "local", title: "Local event", start: eventStart)
            ]),
            includedCalendarIDs: ["work"],
            clock: FixedScheduleClock(now: eventStart.addingTimeInterval(-60 * 60)),
            calendar: calendar
        )
        let tool = GetEventsTool(schedulingService: service, calendar: calendar)

        let output = try await tool.call(
            arguments: GetEventsArguments(
                start: "2026-09-04T10:00:00+02:00",
                end: "2026-09-04T13:00:00+02:00",
                callsOnly: false,
                firstOnly: false
            )
        )

        #expect(output.events.first?.start == "2026-09-04T11:00:00+03:00")
    }

    @Test
    func availabilityToolRejectsInvalidDateInterval() async throws {
        let tool = FindAvailableSlotsTool(
            schedulingService: SchedulingService(
                provider: InMemoryCalendarEventProvider(storedEvents: []),
                includedCalendarIDs: ["work"],
                calendar: utcCalendar()
            ),
            calendar: utcCalendar()
        )

        await #expect(throws: CalendarToolError.invalidDate) {
            try await tool.call(
                arguments: FindAvailableSlotsArguments(
                    date: "2026-08-22",
                    period: .custom,
                    customStart: "2026-08-22T10:00:00Z",
                    customEnd: "2026-08-22T09:00:00Z",
                    durationMinutes: 30,
                    firstOnly: true
                )
            )
        }
    }

    private func makeGetEventsTool() -> GetEventsTool {
        GetEventsTool(
            schedulingService: SchedulingService(
                provider: InMemoryCalendarEventProvider(storedEvents: []),
                includedCalendarIDs: ["work"],
                clock: FixedScheduleClock(now: .distantPast),
                calendar: utcCalendar()
            ),
            calendar: utcCalendar()
        )
    }

    private func event(id: String, title: String, start: Date) -> CalendarEvent {
        CalendarEvent(
            id: id,
            calendarID: "work",
            title: title,
            start: start,
            end: start.addingTimeInterval(30 * 60),
            status: .accepted,
            kind: .event,
            isAllDay: false,
            location: nil,
            conferencingURL: nil
        )
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
