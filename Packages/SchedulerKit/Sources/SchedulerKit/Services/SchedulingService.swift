import Foundation

public struct SchedulingService: Sendable {
    private let provider: any CalendarEventProvider
    private let includedCalendarIDs: Set<String>
    private let workingHours: WorkingHours
    private let clock: any ScheduleClock
    private let calendar: Calendar

    public init(
        provider: any CalendarEventProvider,
        includedCalendarIDs: Set<String>,
        workingHours: WorkingHours = WorkingHours(),
        clock: any ScheduleClock = SystemScheduleClock(),
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.provider = provider
        self.includedCalendarIDs = includedCalendarIDs
        self.workingHours = workingHours
        self.clock = clock
        self.calendar = calendar
    }

    public func dateInterval(for day: ScheduleDay) throws -> DateInterval {
        let date =
            switch day {
            case .today:
                clock.now
            case .tomorrow:
                calendar.date(byAdding: .day, value: 1, to: clock.now) ?? clock.now
            case .date(let date):
                date
            }

        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            throw SchedulingServiceError.invalidLocalDate
        }
        return DateInterval(start: start, end: end)
    }

    public func events(on day: ScheduleDay) async throws -> [CalendarEvent] {
        try await events(in: dateInterval(for: day))
    }

    public func events(
        in interval: DateInterval,
        callsOnly: Bool = false,
        firstOnly: Bool = false
    ) async throws -> [CalendarEvent] {
        guard interval.duration <= 7 * 24 * 60 * 60 else {
            throw SchedulingServiceError.intervalTooLarge
        }

        let matchingEvents = try await provider.events(in: interval)
            .filter { event in
                includedCalendarIDs.contains(event.calendarID)
                    && event.kind == .event
                    && event.status == .accepted
                    && !event.isAllDay
                    && event.start < interval.end
                    && event.end > interval.start
                    && event.end > event.start
                    && (!callsOnly || event.start >= clock.now && isCall(event))
            }
            .sorted { $0.start < $1.start }
        return firstOnly ? Array(matchingEvents.prefix(1)) : matchingEvents
    }

    public func isCall(_ event: CalendarEvent) -> Bool {
        CallClassifier().isCall(event)
    }

    public func findAvailableSlots(
        in interval: DateInterval,
        duration: TimeInterval = 30 * 60,
        firstOnly: Bool = false
    ) async throws -> AvailabilitySearchResult {
        guard (5 * 60 ... 8 * 60 * 60).contains(duration) else {
            throw SchedulingServiceError.invalidDuration
        }
        guard
            let dayEnd = calendar.date(
                byAdding: .day,
                value: 1,
                to: calendar.startOfDay(for: interval.start)
            ),
            interval.end <= dayEnd
        else {
            throw SchedulingServiceError.invalidLocalDate
        }

        let workingInterval = try workingHours.interval(on: interval.start, calendar: calendar)
        let busyIntervals = try await events(in: interval)
            .compactMap { event -> DateInterval? in
                let start = max(event.start, workingInterval.start)
                let end = min(event.end, workingInterval.end)
                return start < end ? DateInterval(start: start, end: end) : nil
            }
        let currentTimeBoundary =
            calendar.isDate(interval.start, inSameDayAs: clock.now) ? clock.now : interval.start
        let searchStart = max(max(interval.start, workingInterval.start), currentTimeBoundary)
        let searchEnd = min(interval.end, workingInterval.end)
        let availableSlots = availableSlots(
            from: searchStart,
            through: searchEnd,
            duration: duration,
            busyIntervals: merge(busyIntervals)
        )

        return AvailabilitySearchResult(
            searchedInterval: interval,
            workingInterval: workingInterval,
            requestedDuration: duration,
            slots: firstOnly ? Array(availableSlots.prefix(1)) : availableSlots
        )
    }

    private func merge(_ intervals: [DateInterval]) -> [DateInterval] {
        intervals.sorted { $0.start < $1.start }.reduce(into: []) { merged, interval in
            guard let last = merged.last, interval.start <= last.end else {
                merged.append(interval)
                return
            }
            merged[merged.count - 1] = DateInterval(
                start: last.start,
                end: max(last.end, interval.end)
            )
        }
    }

    private func availableSlots(
        from start: Date,
        through end: Date,
        duration: TimeInterval,
        busyIntervals: [DateInterval]
    ) -> [DateInterval] {
        var slots: [DateInterval] = []
        var cursor = start

        for busy in busyIntervals where cursor < end {
            appendSlots(from: cursor, through: min(busy.start, end), duration: duration, to: &slots)
            cursor = max(cursor, busy.end)
        }
        appendSlots(from: cursor, through: end, duration: duration, to: &slots)
        return slots
    }

    private func appendSlots(
        from start: Date,
        through end: Date,
        duration: TimeInterval,
        to slots: inout [DateInterval]
    ) {
        var slotStart = start
        while slotStart.addingTimeInterval(duration) <= end {
            let slotEnd = slotStart.addingTimeInterval(duration)
            slots.append(DateInterval(start: slotStart, end: slotEnd))
            slotStart = slotEnd
        }
    }
}
