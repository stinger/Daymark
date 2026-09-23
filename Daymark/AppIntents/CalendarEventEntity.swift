import AppIntents
import CoreSpotlight
import Foundation
import OSLog
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

struct CalendarEventEntityQuery: EntityStringQuery {
    private static let logger = Logger.daymark(category: "CalendarEventEntityQuery")

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
        Self.logger.info("Resolving entities for identifiers=\(identifiers, privacy: .public)")
        guard let interval = await interval(containing: identifiers) else {
            Self.logger.error("Could not resolve entities because no persisted interval matched identifiers=\(identifiers, privacy: .public)")
            return []
        }
        let requested = Set(identifiers)
        let events = try await store.events(in: interval)
        let entities = events.compactMap(CalendarEventEntity.init(demoEvent:))
        let byID = Dictionary(uniqueKeysWithValues: entities.map { ($0.id, $0) })
        let resolved = identifiers.compactMap { requested.contains($0) ? byID[$0] : nil }
        Self.logger.info("Resolved \(resolved.count, privacy: .public) of \(identifiers.count, privacy: .public) identifiers from \(events.count, privacy: .public) events")
        return resolved
    }

    func suggestedEntities() async throws -> [CalendarEventEntity] {
        let events = try await allDemoEvents()
        let entities = events.compactMap(CalendarEventEntity.init(demoEvent:))
        Self.logger.info("Suggested \(entities.count, privacy: .public) demo event entities")
        return entities
    }

    func entities(matching string: String) async throws -> [CalendarEventEntity] {
        let entities = try await suggestedEntities().filter {
            $0.title.localizedStandardContains(string)
        }
        Self.logger.info("Matched \(entities.count, privacy: .public) demo event entities for query=\(string, privacy: .public)")
        return entities
    }

    func cancel(_ entity: CalendarEventEntity) async throws {
        Self.logger.info("Cancelling entityID=\(entity.id, privacy: .public) title=\(entity.title, privacy: .public)")
        let events = try await resolvedDemoEvents(for: [entity.id])
        Self.logger.info("Resolved \(events.count, privacy: .public) calendar events to remove for entityID=\(entity.id, privacy: .public)")
        try await store.removeEvents(withIDs: Set(events.map(\.id)))
        Self.logger.info("Removed calendar events for entityID=\(entity.id, privacy: .public)")
        try await indexer.remove(identifiers: [entity.id])
        Self.logger.info("Removed Spotlight entityID=\(entity.id, privacy: .public)")
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
        guard let interval = await intervalStore.load() else {
            Self.logger.error("No persisted demo schedule interval; returning no demo events")
            return []
        }
        let events = try await store.events(in: interval)
        let demoEvents = events.filter(\.isDaymarkDemoEvent)
        Self.logger.info("Loaded \(demoEvents.count, privacy: .public) demo events from \(events.count, privacy: .public) calendar events in persisted interval")
        return demoEvents
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
