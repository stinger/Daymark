import Foundation
import Testing

@testable import Daymark

struct EventCandidateExtractorTests {
    @Test
    func extractsNearestTitleAndNextFutureOccurrence() throws {
        let calendar = makeCalendar()
        let now = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 20, hour: 12))
        )
        let lines = [
            RecognizedTextLine(text: "Design Review", confidence: 0.98),
            RecognizedTextLine(text: "September 15 at 2:30 PM", confidence: 0.97),
        ]

        let candidates = EventCandidateExtractor(
            calendar: calendar,
            locale: Locale(identifier: "en_US"),
            now: now
        ).extract(from: lines)

        let candidate = try #require(candidates.first)
        #expect(candidate.title == "Design Review")
        #expect(
            calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: candidate.start
            ) == DateComponents(year: 2027, month: 9, day: 15, hour: 14, minute: 30)
        )
    }

    @Test
    func extractsMultipleCandidatesWithTheirNearestTitles() throws {
        let calendar = makeCalendar()
        let now = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))
        )
        let lines = [
            RecognizedTextLine(text: "Breakfast", confidence: 0.9),
            RecognizedTextLine(text: "January 3 at 8:00 AM", confidence: 0.8),
            RecognizedTextLine(text: "Planning Session", confidence: 0.95),
            RecognizedTextLine(text: "January 4 at 1:00 PM", confidence: 0.85),
        ]

        let candidates = EventCandidateExtractor(
            calendar: calendar,
            locale: Locale(identifier: "en_US"),
            now: now
        ).extract(from: lines)

        #expect(candidates.map(\.title) == ["Planning Session", "Breakfast"])
        #expect(candidates.map { calendar.component(.hour, from: $0.start) } == [13, 8])
    }

    @Test
    func combinesAdjacentDateAndTimeLines() throws {
        let calendar = makeCalendar()
        let now = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))
        )
        let lines = [
            RecognizedTextLine(text: "Product Launch", confidence: 0.9),
            RecognizedTextLine(text: "February 10", confidence: 0.9),
            RecognizedTextLine(text: "9:15 AM", confidence: 0.9),
        ]

        let candidates = EventCandidateExtractor(
            calendar: calendar,
            locale: Locale(identifier: "en_US"),
            now: now
        ).extract(from: lines)

        let candidate = try #require(candidates.first)
        #expect(candidate.title == "Product Launch")
        #expect(calendar.component(.hour, from: candidate.start) == 9)
        #expect(calendar.component(.minute, from: candidate.start) == 15)
    }

    @Test
    func honorsLocaleForNumericDatesAndTime() throws {
        var calendar = makeCalendar()
        calendar.locale = Locale(identifier: "en_GB")
        let now = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))
        )

        let candidates = EventCandidateExtractor(
            calendar: calendar,
            locale: Locale(identifier: "en_GB"),
            now: now
        ).extract(from: [RecognizedTextLine(text: "21/9 at 14:30", confidence: 1)])

        let candidate = try #require(candidates.first)
        #expect(calendar.component(.month, from: candidate.start) == 9)
        #expect(calendar.component(.day, from: candidate.start) == 21)
        #expect(calendar.component(.hour, from: candidate.start) == 14)
    }

    @Test
    func combinesDateSplitAcrossInvitationLayout() throws {
        let calendar = makeCalendar()
        let now = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 12))
        )
        let lines = [
            RecognizedTextLine(text: "Kate & Mark", confidence: 1, isTitle: true),
            RecognizedTextLine(text: "24", confidence: 1),
            RecognizedTextLine(text: "SATURDAY", confidence: 1),
            RecognizedTextLine(text: "OCTOBER", confidence: 1),
            RecognizedTextLine(text: "12:00", confidence: 1),
        ]

        let candidate = try #require(
            EventCandidateExtractor(
                calendar: calendar,
                locale: Locale(identifier: "en_US"),
                now: now
            ).extract(from: lines).first
        )

        #expect(candidate.title == "Kate & Mark")
        #expect(
            calendar.dateComponents([.year, .month, .day, .hour, .minute], from: candidate.start)
                == DateComponents(year: 2026, month: 10, day: 24, hour: 12, minute: 0)
        )
    }

    @Test
    func requiresBothDateAndTime() throws {
        let calendar = makeCalendar()
        let now = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))
        )

        let candidates = EventCandidateExtractor(
            calendar: calendar,
            locale: Locale(identifier: "en_US"),
            now: now
        ).extract(from: [RecognizedTextLine(text: "January 3", confidence: 1)])

        #expect(candidates.isEmpty)
    }

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }
}
