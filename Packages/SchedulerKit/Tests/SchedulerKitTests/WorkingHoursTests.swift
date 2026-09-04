import Foundation
import Testing

@testable import SchedulerKit

struct WorkingHoursTests {
    @Test
    func validatesBoundsAndOrdering() {
        #expect(WorkingHours(startHour: 9, endHour: 17).isValid)
        #expect(!WorkingHours(startHour: 17, endHour: 9).isValid)
        #expect(!WorkingHours(startHour: 24, endHour: 25).isValid)
    }

    @Test
    func createsIntervalInConfiguredCalendar() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Sofia"))
        let date = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 4, hour: 12))
        )

        let interval = try WorkingHours(
            startHour: 9,
            startMinute: 30,
            endHour: 17,
            endMinute: 15
        ).interval(on: date, calendar: calendar)

        #expect(calendar.component(.hour, from: interval.start) == 9)
        #expect(calendar.component(.minute, from: interval.start) == 30)
        #expect(calendar.component(.hour, from: interval.end) == 17)
        #expect(calendar.component(.minute, from: interval.end) == 15)
    }
}
