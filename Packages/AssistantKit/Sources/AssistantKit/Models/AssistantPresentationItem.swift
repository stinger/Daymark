import Foundation
import SchedulerKit

public enum AssistantPresentationItem: Sendable, Equatable {
    case event(CalendarEvent)
    case availabilitySlot(DateInterval)
}
