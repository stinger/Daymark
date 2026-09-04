import Foundation

public struct WorkingHours: Sendable, Equatable {
    public let startHour: Int
    public let startMinute: Int
    public let endHour: Int
    public let endMinute: Int

    public init(
        startHour: Int = 9,
        startMinute: Int = 0,
        endHour: Int = 17,
        endMinute: Int = 0
    ) {
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
    }

    public var isValid: Bool {
        guard (0 ... 23).contains(startHour),
            (0 ... 59).contains(startMinute),
            (0 ... 23).contains(endHour),
            (0 ... 59).contains(endMinute)
        else { return false }

        return startHour * 60 + startMinute < endHour * 60 + endMinute
    }

    public func interval(on date: Date, calendar: Calendar) throws -> DateInterval {
        guard
            isValid,
            let start = calendar.date(
                bySettingHour: startHour,
                minute: startMinute,
                second: 0,
                of: date
            ),
            let end = calendar.date(
                bySettingHour: endHour,
                minute: endMinute,
                second: 0,
                of: date
            ),
            start < end
        else {
            throw SchedulingServiceError.invalidWorkingHours
        }

        return DateInterval(start: start, end: end)
    }
}
