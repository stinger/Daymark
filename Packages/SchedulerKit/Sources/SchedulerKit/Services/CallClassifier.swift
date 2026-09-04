import Foundation

public struct CallClassifier: Sendable {
    public init() {}

    public func isCall(_ event: CalendarEvent) -> Bool {
        let searchableText = [event.title, event.location]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()

        if containsMeetingSignal(in: searchableText) {
            return true
        }

        guard let url = event.conferencingURL else {
            return false
        }

        let urlText = url.absoluteString.lowercased()
        return url.scheme?.lowercased() == "tel"
            || url.scheme?.lowercased() == "facetime"
            || urlText.contains("zoom.us")
            || urlText.contains("meet.google.com")
            || urlText.contains("teams.microsoft.com")
            || urlText.contains("teams.live.com")
    }

    private func containsMeetingSignal(in text: String) -> Bool {
        let signals = [
            "call", "meeting", "meet", "sync", "standup", "stand-up",
            "1:1", "one-on-one", "zoom", "google meet", "microsoft teams",
            "facetime", "phone",
        ]
        return signals.contains { text.localizedStandardContains($0) }
    }
}
