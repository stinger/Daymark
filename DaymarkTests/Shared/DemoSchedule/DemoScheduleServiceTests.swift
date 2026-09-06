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
            indexer: NoOpDemoEventIndexer(),
            intervalStore: InMemoryDemoScheduleIntervalStore(),
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
    func creationAndCleanupKeepSpotlightInSyncWithOwnedEvents() async throws {
        let calendar = makeCalendar()
        let now = try date(hour: 8, calendar: calendar)
        let store = InMemoryDemoEventStore()
        let indexer = RecordingDemoEventIndexer()
        let service = DemoScheduleService(
            store: store,
            indexer: indexer,
            intervalStore: InMemoryDemoScheduleIntervalStore(),
            calendar: calendar,
            clock: FixedScheduleClock(now: now)
        )

        _ = try await service.create()
        _ = try await service.create()
        _ = try await service.remove()

        let indexedBatches = await indexer.indexedBatches
        #expect(indexedBatches.count == 2)
        #expect(indexedBatches.allSatisfy { $0.count == 4 })
        #expect(await indexer.removeAllCount == 5)
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
            indexer: NoOpDemoEventIndexer(),
            intervalStore: InMemoryDemoScheduleIntervalStore(),
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

    @Test
    func persistedIntervalDrivesCleanupAfterMidnight() async throws {
        let calendar = makeCalendar()
        let store = InMemoryDemoEventStore()
        let intervalStore = InMemoryDemoScheduleIntervalStore()
        let creation = DemoScheduleService(
            store: store,
            indexer: NoOpDemoEventIndexer(),
            intervalStore: intervalStore,
            calendar: calendar,
            clock: FixedScheduleClock(now: try date(hour: 23, calendar: calendar))
        )
        _ = try await creation.create()

        let cleanup = DemoScheduleService(
            store: store,
            indexer: NoOpDemoEventIndexer(),
            intervalStore: intervalStore,
            calendar: calendar,
            clock: FixedScheduleClock(now: try date(day: 22, hour: 1, calendar: calendar))
        )
        let removed = try await cleanup.remove()

        #expect(removed == 4)
        #expect(await store.snapshot().isEmpty)
        #expect(await intervalStore.load() == nil)
    }

    @Test
    func intervalStorePersistsAcrossInstances() async throws {
        let suiteName = "DemoScheduleIntervalStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let interval = DateInterval(start: Date(timeIntervalSince1970: 100), duration: 200)

        await DemoScheduleIntervalStore(suiteName: suiteName).save(interval)

        #expect(await DemoScheduleIntervalStore(suiteName: suiteName).load() == interval)
    }

    @Test
    func spotlightFailuresDoNotFailCalendarCreationOrRemoval() async throws {
        let calendar = makeCalendar()
        let store = InMemoryDemoEventStore()
        let service = DemoScheduleService(
            store: store,
            indexer: FailingDemoEventIndexer(),
            intervalStore: InMemoryDemoScheduleIntervalStore(),
            calendar: calendar,
            clock: FixedScheduleClock(now: try date(hour: 8, calendar: calendar))
        )

        #expect(try await service.create() == 4)
        #expect(try await service.remove() == 4)
        #expect(await store.snapshot().isEmpty)
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

private actor RecordingDemoEventIndexer: DemoEventIndexing {
    private(set) var indexedBatches: [[CalendarEvent]] = []
    private(set) var removeAllCount = 0

    func index(_ events: [CalendarEvent]) {
        indexedBatches.append(events)
    }

    func remove(identifiers: [String]) {}

    func removeAll() {
        removeAllCount += 1
    }
}

private struct FailingDemoEventIndexer: DemoEventIndexing {
    struct Failure: Error {}

    func index(_ events: [CalendarEvent]) throws { throw Failure() }
    func remove(identifiers: [String]) throws { throw Failure() }
    func removeAll() throws { throw Failure() }
}
