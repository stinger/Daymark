import Foundation
import Testing

@testable import SchedulerKit
struct SchedulingServiceAvailabilityTests {
    @Test
    func emptyDayUsesDefaultWorkingHoursAndThirtyMinuteDuration() async throws {
        let context = try makeContext(events: [], nowHour: 8)

        let result = try await context.service.findAvailableSlots(
            in: try context.service.dateInterval(for: .today)
        )

        #expect(result.requestedDuration == 30 * 60)
        #expect(hour(of: result.workingInterval.start, calendar: context.calendar) == 9)
        #expect(hour(of: result.workingInterval.end, calendar: context.calendar) == 17)
        #expect(result.slots.count == 16)
        #expect(result.slots.first?.start == result.workingInterval.start)
        #expect(result.slots.last?.end == result.workingInterval.end)
    }

    @Test
    func firstOnlyReturnsTheEarliestOpening() async throws {
        let context = try makeContext(events: [], nowHour: 8)

        let result = try await context.service.findAvailableSlots(
            in: try context.service.dateInterval(for: .today),
            firstOnly: true
        )

        #expect(result.slots.count == 1)
        #expect(result.slots.first?.start == result.workingInterval.start)
    }

    @Test(arguments: [4, 481])
    func rejectsDurationsOutsideSupportedMinutes(_ minutes: Int) async throws {
        let context = try makeContext(events: [], nowHour: 8)

        await #expect(throws: SchedulingServiceError.invalidDuration) {
            try await context.service.findAvailableSlots(
                in: try context.service.dateInterval(for: .today),
                duration: TimeInterval(minutes * 60)
            )
        }
    }

    @Test
    func overlappingAndAdjacentEventsProduceOnlyValidBoundaryAndMiddleSlots() async throws {
        let calendar = makeCalendar()
        let events = [
            makeEvent(startHour: 9, endHour: 10, calendar: calendar),
            makeEvent(startHour: 9, startMinute: 30, endHour: 11, calendar: calendar),
            makeEvent(startHour: 11, endHour: 12, calendar: calendar),
            makeEvent(startHour: 13, endHour: 16, calendar: calendar),
        ]
        let context = try makeContext(events: events, nowHour: 8, calendar: calendar)

        let result = try await context.service.findAvailableSlots(
            in: try context.service.dateInterval(for: .today),
            duration: 60 * 60
        )

        #expect(result.slots.count == 2)
        #expect(hour(of: result.slots[0].start, calendar: calendar) == 12)
        #expect(hour(of: result.slots[1].start, calendar: calendar) == 16)
        #expect(
            result.slots.allSatisfy {
                $0.start >= result.workingInterval.start && $0.end <= result.workingInterval.end
            })
    }

    @Test
    func fullyBookedResultPreservesSearchBoundsAndDuration() async throws {
        let calendar = makeCalendar()
        let context = try makeContext(
            events: [makeEvent(startHour: 9, endHour: 17, calendar: calendar)],
            nowHour: 8,
            workingHours: WorkingHours(startHour: 9, endHour: 17),
            calendar: calendar
        )

        let result = try await context.service.findAvailableSlots(
            in: try context.service.dateInterval(for: .today),
            duration: 45 * 60
        )

        #expect(result.slots.isEmpty)
        #expect(result.requestedDuration == 45 * 60)
        #expect(hour(of: result.searchedInterval.start, calendar: calendar) == 0)
        #expect(hour(of: result.workingInterval.start, calendar: calendar) == 9)
        #expect(hour(of: result.workingInterval.end, calendar: calendar) == 17)
    }

    @Test
    func afternoonSearchStartsAtNoonAndReturnsFirstOpeningAfterBusyTime() async throws {
        let calendar = makeCalendar()
        let context = try makeContext(
            events: [makeEvent(startHour: 12, endHour: 13, calendar: calendar)],
            nowHour: 8,
            calendar: calendar
        )

        let result = try await context.service.findAvailableSlots(
            in: makeInterval(startHour: 12, endHour: 24, calendar: calendar),
            duration: 30 * 60
        )

        #expect(
            result.slots.first?.start
                == calendar.date(
                    from: DateComponents(
                        year: 2026,
                        month: 8,
                        day: 21,
                        hour: 13
                    )
                )
        )
        #expect(result.slots.allSatisfy { calendar.component(.hour, from: $0.start) >= 12 })
    }

    @Test
    func availabilitySearchDoesNotReturnSlotsPastUpperBound() async throws {
        let context = try makeContext(events: [], nowHour: 8)

        let result = try await context.service.findAvailableSlots(
            in: makeInterval(
                startHour: 12,
                endHour: 13,
                endMinute: 30,
                calendar: context.calendar
            ),
            duration: 30 * 60
        )

        #expect(result.slots.count == 3)
        #expect(hour(of: try #require(result.slots.first).start, calendar: context.calendar) == 12)
        #expect(
            try #require(result.slots.last).end
                == context.calendar.date(
                    from: DateComponents(year: 2026, month: 8, day: 21, hour: 13, minute: 30)
                ))
    }

    @Test
    func explicitDateDurationAndWorkingHoursOverrideDefaults() async throws {
        let calendar = makeCalendar()
        let context = try makeContext(
            events: [],
            nowHour: 8,
            workingHours: WorkingHours(startHour: 10, endHour: 16),
            calendar: calendar
        )
        let explicitDate = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 23)))

        let result = try await context.service.findAvailableSlots(
            in: try context.service.dateInterval(for: .date(explicitDate)),
            duration: 90 * 60
        )

        #expect(result.slots.count == 4)
        #expect(result.slots.allSatisfy { $0.duration == 90 * 60 })
        #expect(calendar.component(.day, from: result.searchedInterval.start) == 23)
        #expect(hour(of: result.workingInterval.start, calendar: calendar) == 10)
        #expect(hour(of: result.workingInterval.end, calendar: calendar) == 16)
    }

    private func makeContext(
        events: [CalendarEvent],
        nowHour: Int,
        workingHours: WorkingHours = WorkingHours(),
        calendar: Calendar? = nil
    ) throws -> (service: SchedulingService, calendar: Calendar) {
        let calendar = calendar ?? makeCalendar()
        let now = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 21, hour: nowHour)))
        return (
            SchedulingService(
                provider: InMemoryCalendarEventProvider(storedEvents: events),
                includedCalendarIDs: ["work"],
                workingHours: workingHours,
                clock: FixedScheduleClock(now: now),
                calendar: calendar
            ),
            calendar
        )
    }

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }

    private func makeInterval(
        startHour: Int,
        startMinute: Int = 0,
        endHour: Int,
        endMinute: Int = 0,
        calendar: Calendar
    ) -> DateInterval {
        let day = calendar.date(from: DateComponents(year: 2026, month: 8, day: 21))!
        let start = calendar.date(
            bySettingHour: startHour,
            minute: startMinute,
            second: 0,
            of: day
        )!
        let end =
            endHour == 24
            ? calendar.date(byAdding: .day, value: 1, to: day)!
            : calendar.date(
                bySettingHour: endHour,
                minute: endMinute,
                second: 0,
                of: day
            )!
        return DateInterval(start: start, end: end)
    }

    private func makeEvent(
        startHour: Int,
        startMinute: Int = 0,
        endHour: Int,
        calendar: Calendar
    ) -> CalendarEvent {
        let start = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 21, hour: startHour, minute: startMinute))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 8, day: 21, hour: endHour))!
        return CalendarEvent(
            id: "\(startHour):\(startMinute)-\(endHour)",
            calendarID: "work",
            title: "Busy",
            start: start,
            end: end,
            status: .accepted,
            kind: .event,
            isAllDay: false,
            location: nil,
            conferencingURL: nil
        )
    }

    private func hour(of date: Date, calendar: Calendar) -> Int {
        calendar.component(.hour, from: date)
    }
}
