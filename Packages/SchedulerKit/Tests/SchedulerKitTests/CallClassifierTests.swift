import Foundation
import Testing

@testable import SchedulerKit
struct CallClassifierTests {
    @Test
    func recognizesCommonCallAndMeetingSignals() {
        let classifier = CallClassifier()
        let events = [
            makeEvent(title: "Planning meeting"),
            makeEvent(title: "Weekly sync"),
            makeEvent(title: "FaceTime with Sam"),
            makeEvent(title: "Project review", location: "Zoom"),
            makeEvent(title: "Project review", url: URL(string: "https://meet.google.com/abc-defg-hij")),
            makeEvent(
                title: "Project review",
                url: URL(string: "https://teams.microsoft.com/l/meetup-join/example")),
            makeEvent(title: "Project review", url: URL(string: "https://example.zoom.us/j/123")),
            makeEvent(title: "Project review", url: URL(string: "tel:+15551234567")),
        ]

        for event in events {
            #expect(
                classifier.isCall(event),
                "Expected \(event.title) / \(event.conferencingURL?.absoluteString ?? "no URL") to be classified as a call"
            )
        }
    }

    @Test
    func doesNotClassifyUnrelatedTimedEvent() {
        let event = makeEvent(title: "Focus block", location: "Home office")

        #expect(!CallClassifier().isCall(event))
    }

    private func makeEvent(
        title: String,
        location: String? = nil,
        url: URL? = nil
    ) -> CalendarEvent {
        CalendarEvent(
            id: title,
            calendarID: "work",
            title: title,
            start: Date(timeIntervalSince1970: 100),
            end: Date(timeIntervalSince1970: 200),
            status: .accepted,
            kind: .event,
            isAllDay: false,
            location: location,
            conferencingURL: url
        )
    }
}
