import Foundation
import SchedulerKit

enum DemoEventOwnership {
    static let scheme = "schedule-assistant-demo"

    static func owns(_ event: CalendarEvent) -> Bool {
        event.title.hasPrefix("Demo -") && event.conferencingURL?.scheme == scheme
    }
}

extension CalendarEvent {
    var isDaymarkDemoEvent: Bool {
        DemoEventOwnership.owns(self)
    }
}
