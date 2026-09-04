import Foundation

public struct CalendarEvent: Identifiable, Sendable, Equatable {
    public let id: String
    public let calendarID: String
    public let title: String
    public let start: Date
    public let end: Date
    public let status: CalendarEventStatus
    public let kind: CalendarItemKind
    public let isAllDay: Bool
    public let location: String?
    public let conferencingURL: URL?

    public init(
        id: String,
        calendarID: String,
        title: String,
        start: Date,
        end: Date,
        status: CalendarEventStatus,
        kind: CalendarItemKind,
        isAllDay: Bool,
        location: String?,
        conferencingURL: URL?
    ) {
        self.id = id
        self.calendarID = calendarID
        self.title = title
        self.start = start
        self.end = end
        self.status = status
        self.kind = kind
        self.isAllDay = isAllDay
        self.location = location
        self.conferencingURL = conferencingURL
    }
}
