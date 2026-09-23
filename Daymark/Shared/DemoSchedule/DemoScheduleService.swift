import Foundation
import OSLog
import SchedulerKit

struct DemoScheduleService: Sendable {
    private static let logger = Logger.daymark(category: "Demo Spotlight")

    private let store: any DemoEventStore
    private let indexer: any DemoEventIndexing
    private let intervalStore: any DemoScheduleIntervalStoring
    private let calendar: Calendar
    private let clock: any ScheduleClock

    init(
        store: any DemoEventStore,
        indexer: any DemoEventIndexing = DemoEventSpotlightIndexer(),
        intervalStore: any DemoScheduleIntervalStoring = DemoScheduleIntervalStore(),
        calendar: Calendar = .autoupdatingCurrent,
        clock: any ScheduleClock = SystemScheduleClock()
    ) {
        self.store = store
        self.indexer = indexer
        self.intervalStore = intervalStore
        self.calendar = calendar
        self.clock = clock
    }

    func create() async throws -> Int {
        let day = try dayInterval()
        _ = try await removeGeneratedEvents(in: await intervalStore.load() ?? day)
        let definitions = try definitions(for: day.start)
        await intervalStore.save(day)
        try await store.saveDemoEvents(definitions)
        await replaceSpotlightIndex(withEventsIn: day)
        return definitions.count
    }

    func remove() async throws -> Int {
        let interval = try await intervalStore.load() ?? dayInterval()
        return try await removeGeneratedEvents(in: interval)
    }

    private func removeGeneratedEvents(in interval: DateInterval) async throws -> Int {
        let generatedEvents = try await store.events(in: interval)
            .filter(\.isDaymarkDemoEvent)
        try await store.removeEvents(withIDs: Set(generatedEvents.map(\.id)))
        await intervalStore.clear()
        await removeSpotlightIndex()
        return generatedEvents.count
    }

    private func replaceSpotlightIndex(withEventsIn interval: DateInterval) async {
        do {
            let generatedEvents = try await store.events(in: interval)
                .filter(\.isDaymarkDemoEvent)
            try await indexer.removeAll()
            try await indexer.index(generatedEvents)
        } catch {
            Self.logger.error("Could not replace demo Spotlight index: \(error, privacy: .public)")
        }
    }

    private func removeSpotlightIndex() async {
        do {
            try await indexer.removeAll()
        } catch {
            Self.logger.error("Could not remove demo Spotlight index: \(error, privacy: .public)")
        }
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
                title: "Lunch Break",
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
        guard let ownershipURL = URL(string: "\(DemoEventOwnership.scheme)://event/\(id)") else {
            throw SchedulingServiceError.invalidLocalDate
        }
        return DemoEventDefinition(
            id: id,
            title: "Demo - \(title)",
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
