import CoreSpotlight
import Foundation
import SchedulerKit
import Testing

@testable import Daymark

struct DemoEventSpotlightTests {
    @Test
    func entityMapsOnlyDocumentedDemoMetadata() throws {
        let event = makeEvent(
            id: "event-123",
            title: "[Demo] Planning",
            location: "Private room",
            conferencingURL: URL(string: "schedule-assistant-demo://event/planning")
        )

        let entity = try #require(CalendarEventEntity(demoEvent: event))
        let attributes = entity.attributeSet

        #expect(entity.title == "[Demo] Planning")
        #expect(entity.start == event.start)
        #expect(entity.end == event.end)
        #expect(attributes.title == "[Demo] Planning")
        #expect(attributes.startDate == event.start)
        #expect(attributes.endDate == event.end)
        #expect(attributes.contentDescription == nil)
        #expect(attributes.contentURL == nil)
    }

    @Test
    func entityRejectsCalendarEventsNotOwnedByDaymarkDemo() {
        let event = makeEvent(
            id: "personal-event",
            title: "Doctor appointment",
            location: "Clinic",
            conferencingURL: nil
        )

        #expect(CalendarEventEntity(demoEvent: event) == nil)
    }

    @Test
    func queryResolvesIdentifiersWithOneBatchedCalendarRead() async throws {
        let first = makeEvent(id: "first", title: "[Demo] First")
        let second = makeEvent(
            id: "second",
            title: "[Demo] Second",
            start: Date(timeIntervalSince1970: 1_800_086_400)
        )
        let unrelated = makeEvent(
            id: "unrelated",
            title: "Personal",
            conferencingURL: nil
        )
        let store = QueryRecordingDemoEventStore(events: [first, second, unrelated])
        let query = CalendarEventEntityQuery(
            store: store,
            intervalStore: InMemoryDemoScheduleIntervalStore(
                interval: interval(containing: [first, second])
            )
        )
        let identifiers = try [
            #require(CalendarEventEntity(demoEvent: first)).id,
            #require(CalendarEventEntity(demoEvent: second)).id,
        ]

        let entities = try await query.entities(for: identifiers)

        #expect(entities.map(\.title) == ["[Demo] First", "[Demo] Second"])
        #expect(await store.readCount == 1)
    }

    @Test
    func queryReturnsEmptyWhenNoDemoEventsExist() async throws {
        let store = QueryRecordingDemoEventStore(events: [])
        let event = makeEvent(id: "missing", title: "[Demo] Missing")
        let query = CalendarEventEntityQuery(
            store: store,
            intervalStore: InMemoryDemoScheduleIntervalStore(
                interval: interval(containing: [event])
            )
        )
        let identifier = try #require(CalendarEventEntity(demoEvent: event)).id

        let entities = try await query.entities(for: [identifier])

        #expect(entities.isEmpty)
        #expect(await store.readCount == 1)
    }

    @Test
    func partialReindexDeletesEveryRequestedIDBeforeIndexingResolvedEvents() async throws {
        let event = makeEvent(id: "resolved", title: "[Demo] Resolved")
        let resolvedID = try #require(CalendarEventEntity(demoEvent: event)).id
        let missingID = try #require(
            CalendarEventEntity(demoEvent: makeEvent(id: "missing", title: "[Demo] Missing"))
        ).id
        let indexer = QueryRecordingDemoEventIndexer()
        let query = CalendarEventEntityQuery(
            store: QueryRecordingDemoEventStore(events: [event]),
            indexer: indexer,
            intervalStore: InMemoryDemoScheduleIntervalStore(
                interval: interval(containing: [event])
            )
        )

        try await query.replaceEntities(for: [resolvedID, missingID])

        #expect(await indexer.removedIdentifiers == [[resolvedID, missingID]])
        #expect(await indexer.indexedBatches.map { $0.map(\.id) } == [["resolved"]])
        #expect(await indexer.operations == ["removeIDs", "index"])
    }

    @Test
    func fullReindexDeletesTypeBeforeReadingPersistedIntervalAndRebuilding() async throws {
        let inside = makeEvent(id: "inside", title: "[Demo] Inside")
        let outside = makeEvent(
            id: "outside",
            title: "[Demo] Outside",
            start: inside.start.addingTimeInterval(86_400)
        )
        let intervalStore = InMemoryDemoScheduleIntervalStore(
            interval: DateInterval(start: inside.start, duration: 3_600)
        )
        let indexer = QueryRecordingDemoEventIndexer()
        let query = CalendarEventEntityQuery(
            store: QueryRecordingDemoEventStore(events: [inside, outside]),
            indexer: indexer,
            intervalStore: intervalStore
        )

        try await query.replaceAllEntities()

        #expect(await indexer.removeAllCount == 1)
        #expect(await indexer.indexedBatches.map { $0.map(\.id) } == [["inside"]])
        #expect(await indexer.operations == ["removeAll", "index"])
    }

    @Test
    func queryPreservesCalendarAuthorizationFailure() async {
        let store = QueryRecordingDemoEventStore(
            events: [],
            failure: CalendarEventProviderError.accessRequired
        )
        let event = makeEvent(id: "missing", title: "[Demo] Missing")
        let query = CalendarEventEntityQuery(
            store: store,
            intervalStore: InMemoryDemoScheduleIntervalStore(
                interval: interval(containing: [event])
            )
        )
        let identifier = CalendarEventEntity(demoEvent: event)!.id

        do {
            _ = try await query.entities(for: [identifier])
            Issue.record("Expected calendar authorization failure")
        } catch CalendarEventProviderError.accessRequired {
            // Expected: queries must not turn denied access into an empty result.
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    private func interval(containing events: [CalendarEvent]) -> DateInterval {
        DateInterval(
            start: events.map(\.start).min()!,
            end: events.map(\.end).max()!
        )
    }

    private func makeEvent(
        id: String,
        title: String,
        start: Date = Date(timeIntervalSince1970: 1_800_000_000),
        location: String? = nil,
        conferencingURL: URL? = URL(string: "schedule-assistant-demo://event/test")
    ) -> CalendarEvent {
        CalendarEvent(
            id: id,
            calendarID: "demo",
            title: title,
            start: start,
            end: start.addingTimeInterval(1_800),
            status: .accepted,
            kind: .event,
            isAllDay: false,
            location: location,
            conferencingURL: conferencingURL
        )
    }
}

private actor QueryRecordingDemoEventIndexer: DemoEventIndexing {
    private(set) var indexedBatches: [[CalendarEvent]] = []
    private(set) var removedIdentifiers: [[String]] = []
    private(set) var removeAllCount = 0
    private(set) var operations: [String] = []

    func index(_ events: [CalendarEvent]) {
        operations.append("index")
        indexedBatches.append(events)
    }

    func remove(identifiers: [String]) {
        operations.append("removeIDs")
        removedIdentifiers.append(identifiers)
    }

    func removeAll() {
        operations.append("removeAll")
        removeAllCount += 1
    }
}

private actor QueryRecordingDemoEventStore: DemoEventStore {
    let storedEvents: [CalendarEvent]
    let failure: CalendarEventProviderError?
    private(set) var readCount = 0

    init(events: [CalendarEvent], failure: CalendarEventProviderError? = nil) {
        storedEvents = events
        self.failure = failure
    }

    func events(in interval: DateInterval) throws -> [CalendarEvent] {
        readCount += 1
        if let failure {
            throw failure
        }
        return storedEvents.filter { $0.start < interval.end && $0.end > interval.start }
    }

    func saveDemoEvents(_ events: [DemoEventDefinition]) {}

    func removeEvents(withIDs ids: Set<String>) {}
}
