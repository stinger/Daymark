import Foundation

public enum ScheduleFormatters {
    public static func localDay(calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    public static func localTimestamp(calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.isLenient = false
        return formatter
    }

    public static func modelDate(_ value: String, calendar: Calendar) -> Date? {
        if value.count == 19 {
            return localTimestamp(calendar: calendar).date(from: value)
        }

        return ISO8601DateFormatter().date(from: value)
    }

    public static func displayTime(calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale.current
        formatter.timeZone = calendar.timeZone
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }

    public static func iso8601(timeZone: TimeZone) -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = timeZone
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }
}
