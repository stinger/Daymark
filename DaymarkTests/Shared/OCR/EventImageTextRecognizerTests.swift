import Foundation
import Testing

@testable import Daymark

struct EventImageTextRecognizerTests {
    @Test
    func recognizesWeddingInvitationDate() async throws {
        let url = try #require(Bundle(for: FixtureToken.self).url(forResource: "Event3", withExtension: "png"))
        let lines = try await EventImageTextRecognizer().recognize(Data(contentsOf: url))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 12)))

        let candidate = try #require(
            EventCandidateExtractor(
                calendar: calendar,
                locale: Locale(identifier: "en_US"),
                now: now
            ).extract(from: lines).first,
            "Recognized lines: \(lines.map(\.text))"
        )

        #expect(
            calendar.dateComponents([.year, .month, .day, .hour, .minute], from: candidate.start)
                == DateComponents(year: 2026, month: 10, day: 24, hour: 12, minute: 0),
            "Recognized lines: \(lines.map(\.text))"
        )
    }

    @Test
    func recognizesEventFixture() async throws {
        let url = try #require(Bundle(for: FixtureToken.self).url(forResource: "Event", withExtension: "png"))
        let lines = try await EventImageTextRecognizer().recognize(Data(contentsOf: url))

        #expect(lines.contains { $0.text.contains("Sep 23, 2026") })

        let candidates = EventCandidateExtractor(
            calendar: .autoupdatingCurrent,
            locale: Locale(identifier: "en_US"),
            now: Date(timeIntervalSince1970: 1_756_000_000)
        ).extract(from: lines)
        let candidate = try #require(
            candidates.first,
            "Recognized lines: \(lines.map(\.text))"
        )
        #expect(candidate.title == "Next generation app UX: Appintents + FoundationModels")
    }
}

private final class FixtureToken: NSObject {}
