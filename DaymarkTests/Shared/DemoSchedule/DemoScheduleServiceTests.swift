import Foundation
import SchedulerKit
import Testing

@testable import Daymark

struct DemoScheduleServiceTests {
    @Test
    func createsPredictableSchedule() async throws {
        let calendar = makeCalendar()
        let now = try date(hour: 8, calendar: calendar)
        let store = InMemoryDemoEventStore()
        let service = DemoScheduleService(
            store: store,
            calendar: calendar,
            clock: FixedScheduleClock(now: now)
        )

        let createdCount = try await service.create()
        let events = await store.snapshot()

        #expect(createdCount == 4)
        #expect(
            events.map(\.title) == [
                "[Demo] Morning Call",
                "[Demo] Focus Block",
                "[Demo] Lunch",
                "[Demo] Afternoon Meeting",
            ]
        )
        #expect(events.allSatisfy { calendar.component(.day, from: $0.start) == 22 })
    }

    @Test
    func repeatedCreationReplacesGeneratedEventsAndCleanupPreservesUnrelatedEvents() async throws {
        let calendar = makeCalendar()
        let now = try date(hour: 8, calendar: calendar)
        let unrelated = CalendarEvent(
            id: "unrelated",
            calendarID: "work",
            title: "Real appointment",
            start: try date(day: 22, hour: 9, minute: 30, calendar: calendar),
            end: try date(day: 22, hour: 10, calendar: calendar),
            status: .accepted,
            kind: .event,
            isAllDay: false,
            location: nil,
            conferencingURL: nil
        )
        let store = InMemoryDemoEventStore(events: [unrelated])
        let service = DemoScheduleService(
            store: store,
            calendar: calendar,
            clock: FixedScheduleClock(now: now)
        )

        _ = try await service.create()
        _ = try await service.create()
        let afterRepeatedCreation = await store.snapshot()
        let removedCount = try await service.remove()
        let afterCleanup = await store.snapshot()

        #expect(afterRepeatedCreation.count == 5)
        #expect(removedCount == 4)
        #expect(afterCleanup == [unrelated])
    }

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }

    private func date(
        day: Int = 21,
        hour: Int,
        minute: Int = 0,
        calendar: Calendar
    ) throws -> Date {
        try #require(
            calendar.date(
                from: DateComponents(year: 2026, month: 8, day: day, hour: hour, minute: minute)
            )
        )
    }
}
