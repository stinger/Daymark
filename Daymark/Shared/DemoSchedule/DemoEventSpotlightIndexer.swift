import CoreSpotlight
import Foundation
import SchedulerKit

protocol DemoEventIndexing: Sendable {
    func index(_ events: [CalendarEvent]) async throws
    func remove(identifiers: [String]) async throws
    func removeAll() async throws
}

struct DemoEventSpotlightIndexer: DemoEventIndexing {
    func index(_ events: [CalendarEvent]) async throws {
        let entities = events.compactMap(CalendarEventEntity.init(demoEvent:))
        guard !entities.isEmpty else { return }
        try await CSSearchableIndex.default().indexAppEntities(entities)
    }

    func remove(identifiers: [String]) async throws {
        guard !identifiers.isEmpty else { return }
        try await CSSearchableIndex.default().deleteAppEntities(
            identifiedBy: identifiers,
            ofType: CalendarEventEntity.self
        )
    }

    func removeAll() async throws {
        try await CSSearchableIndex.default().deleteAppEntities(ofType: CalendarEventEntity.self)
    }
}

struct NoOpDemoEventIndexer: DemoEventIndexing {
    func index(_ events: [CalendarEvent]) {}
    func remove(identifiers: [String]) {}
    func removeAll() {}
}
