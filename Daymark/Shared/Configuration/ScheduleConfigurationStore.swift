import Foundation
import SchedulerKit

@MainActor
final class ScheduleConfigurationStore {
    private static let includedCalendarIDsKey = "includedCalendarIDs"
    private static let workingStartHourKey = "workingStartHour"
    private static let workingStartMinuteKey = "workingStartMinute"
    private static let workingEndHourKey = "workingEndHour"
    private static let workingEndMinuteKey = "workingEndMinute"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func configuration(visibleCalendarIDs: Set<String>) -> ScheduleConfiguration {
        let includedCalendarIDs = resolvedCalendarIDs(visibleCalendarIDs: visibleCalendarIDs)
        let workingHours = resolvedWorkingHours()
        return ScheduleConfiguration(
            includedCalendarIDs: includedCalendarIDs,
            workingHours: workingHours
        )
    }

    func save(_ configuration: ScheduleConfiguration) {
        defaults.set(
            configuration.includedCalendarIDs.sorted(),
            forKey: Self.includedCalendarIDsKey
        )
        let hours = configuration.workingHours
        defaults.set(hours.startHour, forKey: Self.workingStartHourKey)
        defaults.set(hours.startMinute, forKey: Self.workingStartMinuteKey)
        defaults.set(hours.endHour, forKey: Self.workingEndHourKey)
        defaults.set(hours.endMinute, forKey: Self.workingEndMinuteKey)
    }

    private func resolvedCalendarIDs(visibleCalendarIDs: Set<String>) -> Set<String> {
        guard let savedIDs = defaults.stringArray(forKey: Self.includedCalendarIDsKey) else {
            return visibleCalendarIDs
        }

        return Set(savedIDs).intersection(visibleCalendarIDs)
    }

    private func resolvedWorkingHours() -> WorkingHours {
        let keys = [
            Self.workingStartHourKey,
            Self.workingStartMinuteKey,
            Self.workingEndHourKey,
            Self.workingEndMinuteKey,
        ]
        guard keys.allSatisfy({ defaults.object(forKey: $0) != nil }) else {
            return WorkingHours()
        }

        let hours = WorkingHours(
            startHour: defaults.integer(forKey: Self.workingStartHourKey),
            startMinute: defaults.integer(forKey: Self.workingStartMinuteKey),
            endHour: defaults.integer(forKey: Self.workingEndHourKey),
            endMinute: defaults.integer(forKey: Self.workingEndMinuteKey)
        )
        return hours.isValid ? hours : WorkingHours()
    }
}
