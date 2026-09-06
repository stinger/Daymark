import Foundation

protocol DemoScheduleIntervalStoring: Sendable {
    func load() async -> DateInterval?
    func save(_ interval: DateInterval) async
    func clear() async
}

actor DemoScheduleIntervalStore: DemoScheduleIntervalStoring {
    private static let startKey = "demoScheduleIntervalStart"
    private static let endKey = "demoScheduleIntervalEnd"

    private let defaults: UserDefaults

    init(suiteName: String? = nil) {
        defaults = suiteName.flatMap { UserDefaults(suiteName: $0) } ?? .standard
    }

    func load() -> DateInterval? {
        guard
            let start = defaults.object(forKey: Self.startKey) as? Date,
            let end = defaults.object(forKey: Self.endKey) as? Date,
            start < end
        else {
            return nil
        }
        return DateInterval(start: start, end: end)
    }

    func save(_ interval: DateInterval) {
        defaults.set(interval.start, forKey: Self.startKey)
        defaults.set(interval.end, forKey: Self.endKey)
    }

    func clear() {
        defaults.removeObject(forKey: Self.startKey)
        defaults.removeObject(forKey: Self.endKey)
    }
}

actor InMemoryDemoScheduleIntervalStore: DemoScheduleIntervalStoring {
    private var interval: DateInterval?

    init(interval: DateInterval? = nil) {
        self.interval = interval
    }

    func load() -> DateInterval? { interval }
    func save(_ interval: DateInterval) { self.interval = interval }
    func clear() { interval = nil }
}
