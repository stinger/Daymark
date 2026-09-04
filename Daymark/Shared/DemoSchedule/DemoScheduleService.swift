import Foundation
import SchedulerKit

struct DemoScheduleService: Sendable {
    private static let ownershipScheme = "schedule-assistant-demo"

    private let store: any DemoEventStore
    private let calendar: Calendar
    private let clock: any ScheduleClock

    init(
        store: any DemoEventStore,
        calendar: Calendar = .autoupdatingCurrent,
        clock: any ScheduleClock = SystemScheduleClock()
    ) {
        self.store = store
        self.calendar = calendar
        self.clock = clock
    }

    func create() async throws -> Int {
        let day = try dayInterval()
        _ = try await removeGeneratedEvents(in: day)
        let definitions = try definitions(for: day.start)
        try await store.saveDemoEvents(definitions)
        return definitions.count
    }

    func remove() async throws -> Int {
        try await removeGeneratedEvents(in: dayInterval())
    }

    private func removeGeneratedEvents(in interval: DateInterval) async throws -> Int {
        let generatedIDs = Set(
            try await store.events(in: interval)
                .filter(isGeneratedEvent)
                .map(\.id)
        )
        try await store.removeEvents(withIDs: generatedIDs)
        return generatedIDs.count
    }

    private func isGeneratedEvent(_ event: CalendarEvent) -> Bool {
        event.title.hasPrefix("[Demo]")
            && event.conferencingURL?.scheme == Self.ownershipScheme
    }

    private func dayInterval() throws -> DateInterval {
        let today = calendar.startOfDay(for: clock.now)
        guard
            let start = calendar.date(byAdding: .day, value: 1, to: today),
            let end = calendar.date(byAdding: .day, value: 1, to: start)
        else {
            throw SchedulingServiceError.invalidLocalDate
        }
        return DateInterval(start: start, end: end)
    }

    private func definitions(for day: Date) throws -> [DemoEventDefinition] {
        try [
            definition(
                id: "morning-call",
                title: "Morning Call",
                startHour: 9,
                startMinute: 0,
                endHour: 9,
                endMinute: 30,
                day: day,
                location: "Zoom"
            ),
            definition(
                id: "focus-block",
                title: "Focus Block",
                startHour: 10,
                startMinute: 0,
                endHour: 12,
                endMinute: 0,
                day: day
            ),
            definition(
                id: "lunch",
                title: "Lunch",
                startHour: 12,
                startMinute: 0,
                endHour: 13,
                endMinute: 0,
                day: day
            ),
            definition(
                id: "afternoon-meeting",
                title: "Afternoon Meeting",
                startHour: 14,
                startMinute: 0,
                endHour: 15,
                endMinute: 0,
                day: day
            ),
        ]
    }

    private func definition(
        id: String,
        title: String,
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
        day: Date,
        location: String? = nil
    ) throws -> DemoEventDefinition {
        guard let ownershipURL = URL(string: "\(Self.ownershipScheme)://event/\(id)") else {
            throw SchedulingServiceError.invalidLocalDate
        }
        return DemoEventDefinition(
            id: id,
            title: "[Demo] \(title)",
            start: try date(on: day, hour: startHour, minute: startMinute),
            end: try date(on: day, hour: endHour, minute: endMinute),
            location: location,
            ownershipURL: ownershipURL
        )
    }

    private func date(on day: Date, hour: Int, minute: Int) throws -> Date {
        guard let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) else {
            throw SchedulingServiceError.invalidLocalDate
        }
        return date
    }
}
