import Foundation

public protocol CalendarEventProvider: Sendable {
    func events(in interval: DateInterval) async throws -> [CalendarEvent]
}
