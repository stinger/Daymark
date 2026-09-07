import AppIntents
import CoreSpotlight
import Foundation
import SchedulerKit

struct CalendarEventEntity: IndexedEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Daymark Demo Event")
    static let defaultQuery = CalendarEventEntityQuery()

    let id: String

    @Property(indexingKey: \.title)
    var title: String

    @Property(indexingKey: \.startDate)
    var start: Date

    @Property(indexingKey: \.endDate)
    var end: Date

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(start.formatted(date: .abbreviated, time: .shortened))"
        )
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = defaultAttributeSet
        attributes.title = title
        attributes.startDate = start
        attributes.endDate = end
        return attributes
    }

    init?(demoEvent event: CalendarEvent) {
        guard event.isDaymarkDemoEvent else { return nil }
        id = Self.identifier(for: event)
        title = event.title
        start = event.start
        end = event.end
    }

    // EventKit identifiers can change after a sync. Including the occurrence start keeps
    // recurring demo occurrences distinct and lets the query resolve a batch with one fetch.
    fileprivate static func identifier(for event: CalendarEvent) -> String {
        let encodedEventID = Data(event.id.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "v1.\(Int(event.start.timeIntervalSince1970)).\(encodedEventID)"
    }

    fileprivate static func eventStart(from identifier: String) -> Date? {
        let components = identifier.split(separator: ".", maxSplits: 2)
        guard
            components.count == 3,
            components[0] == "v1",
            let timestamp = TimeInterval(components[1])
        else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp)
    }
}

struct CalendarEventEntityQuery: EntityQuery {
    private let store: any DemoEventStore
    private let indexer: any DemoEventIndexing
    private let intervalStore: any DemoScheduleIntervalStoring
    private let calendar: Calendar

    init() {
        store = EventKitCalendarProvider()
        indexer = DemoEventSpotlightIndexer()
        intervalStore = DemoScheduleIntervalStore()
        calendar = .autoupdatingCurrent
    }

    init(
        store: any DemoEventStore,
        indexer: any DemoEventIndexing = NoOpDemoEventIndexer(),
        intervalStore: any DemoScheduleIntervalStoring = InMemoryDemoScheduleIntervalStore(),
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.store = store
        self.indexer = indexer
        self.intervalStore = intervalStore
        self.calendar = calendar
    }

    func entities(for identifiers: [CalendarEventEntity.ID]) async throws -> [CalendarEventEntity] {
        guard let interval = await interval(containing: identifiers) else { return [] }
        let requested = Set(identifiers)
        let entities = try await store.events(in: interval)
            .compactMap(CalendarEventEntity.init(demoEvent:))
        let byID = Dictionary(uniqueKeysWithValues: entities.map { ($0.id, $0) })
        return identifiers.compactMap { requested.contains($0) ? byID[$0] : nil }
    }

    func suggestedEntities() async throws -> [CalendarEventEntity] {
        try await allDemoEvents().compactMap(CalendarEventEntity.init(demoEvent:))
    }

    private func resolvedDemoEvents(for identifiers: [CalendarEventEntity.ID]) async throws
        -> [CalendarEvent]
    {
        guard let interval = await interval(containing: identifiers) else { return [] }
        let requested = Set(identifiers)
        return try await store.events(in: interval)
            .filter { event in
                guard let entity = CalendarEventEntity(demoEvent: event) else { return false }
                return requested.contains(entity.id)
            }
    }

    private func allDemoEvents() async throws -> [CalendarEvent] {
        guard let interval = await intervalStore.load() else { return [] }
        return try await store.events(in: interval).filter(\.isDaymarkDemoEvent)
    }

    func replaceEntities(for identifiers: [CalendarEventEntity.ID]) async throws {
        try await indexer.remove(identifiers: identifiers)
        try await indexer.index(resolvedDemoEvents(for: identifiers))
    }

    func replaceAllEntities() async throws {
        try await indexer.removeAll()
        try await indexer.index(allDemoEvents())
    }

    private func interval(containing identifiers: [CalendarEventEntity.ID]) async -> DateInterval? {
        let starts = identifiers.compactMap(CalendarEventEntity.eventStart(from:))
        guard
            let persistedInterval = await intervalStore.load(),
            let earliest = starts.min(),
            let latest = starts.max(),
            let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: latest))
        else {
            return nil
        }
        return DateInterval(start: calendar.startOfDay(for: earliest), end: end)
            .intersection(with: persistedInterval)
    }

}

#if canImport(AppIntents.IndexedEntityQuery)
    @available(iOS 27.0, *)
    extension CalendarEventEntityQuery: IndexedEntityQuery {
        func reindexEntities(
            for identifiers: [CalendarEventEntity.ID],
            indexDescription: CSSearchableIndexDescription
        ) async throws {
            try await replaceEntities(for: identifiers)
        }

        func reindexAllEntities(indexDescription: CSSearchableIndexDescription) async throws {
            try await replaceAllEntities()
        }
    }
#endif
