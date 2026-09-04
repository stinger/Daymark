import Foundation
import SchedulerKit

actor AssistantToolResultStore {
    private var items: [AssistantPresentationItem] = []

    func record(events: [CalendarEvent]) {
        items.append(contentsOf: events.map(AssistantPresentationItem.event))
    }

    func record(availabilitySlots: [DateInterval]) {
        items.append(contentsOf: availabilitySlots.map(AssistantPresentationItem.availabilitySlot))
    }

    func recordedItems() -> [AssistantPresentationItem] {
        items
    }
}
