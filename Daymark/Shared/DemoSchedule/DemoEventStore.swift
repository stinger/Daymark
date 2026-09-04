import Foundation
import SchedulerKit

protocol DemoEventStore: Sendable {
    func events(in interval: DateInterval) async throws -> [CalendarEvent]
    func saveDemoEvents(_ events: [DemoEventDefinition]) async throws
    func removeEvents(withIDs ids: Set<String>) async throws
}
