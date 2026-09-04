import Foundation
import SchedulerKit
import Testing

@testable import Daymark

@MainActor
struct ScheduleConfigurationStoreTests {
    @Test
    func defaultsToVisibleCalendarsAndStandardWorkingHours() throws {
        let (store, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = store.configuration(visibleCalendarIDs: ["work", "personal"])

        #expect(configuration.includedCalendarIDs == ["work", "personal"])
        #expect(configuration.workingHours == WorkingHours())
    }

    @Test
    func persistsExplicitSelectionAndValidWorkingHours() throws {
        let (store, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let hours = WorkingHours(startHour: 8, startMinute: 30, endHour: 16, endMinute: 45)
        store.save(
            ScheduleConfiguration(includedCalendarIDs: ["work"], workingHours: hours)
        )

        let configuration = ScheduleConfigurationStore(defaults: defaults)
            .configuration(visibleCalendarIDs: ["work", "personal", "new"])

        #expect(configuration.includedCalendarIDs == ["work"])
        #expect(configuration.workingHours == hours)
    }

    @Test
    func preservesAnExplicitlyEmptyCalendarSelection() throws {
        let (store, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        store.save(
            ScheduleConfiguration(includedCalendarIDs: [], workingHours: WorkingHours())
        )

        let configuration = store.configuration(visibleCalendarIDs: ["work"])

        #expect(configuration.includedCalendarIDs.isEmpty)
    }

    @Test
    func reconcilesVisibleCalendarsWithoutRepairingStorage() throws {
        let (store, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        store.save(
            ScheduleConfiguration(
                includedCalendarIDs: ["work", "temporarily-hidden"],
                workingHours: WorkingHours()
            )
        )

        let configuration = store.configuration(visibleCalendarIDs: ["work"])
        let reloaded = store.configuration(
            visibleCalendarIDs: ["work", "temporarily-hidden"]
        )

        #expect(configuration.includedCalendarIDs == ["work"])
        #expect(reloaded.includedCalendarIDs == ["work", "temporarily-hidden"])
    }

    @Test
    func missingSelectionDefaultsToVisibleCalendarsWithoutPersisting() throws {
        let (store, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let initial = store.configuration(visibleCalendarIDs: ["work"])
        let refreshed = store.configuration(visibleCalendarIDs: ["personal"])

        #expect(initial.includedCalendarIDs == ["work"])
        #expect(refreshed.includedCalendarIDs == ["personal"])
        #expect(defaults.object(forKey: "includedCalendarIDs") == nil)
    }

    @Test(
        arguments: [
            WorkingHours(startHour: -1, startMinute: 0, endHour: 17, endMinute: 0),
            WorkingHours(startHour: 9, startMinute: 60, endHour: 17, endMinute: 0),
            WorkingHours(startHour: 9, startMinute: 0, endHour: 24, endMinute: 0),
            WorkingHours(startHour: 9, startMinute: 0, endHour: 17, endMinute: -1),
            WorkingHours(startHour: 17, startMinute: 0, endHour: 9, endMinute: 0),
            WorkingHours(startHour: 9, startMinute: 0, endHour: 9, endMinute: 0),
        ]
    )
    func invalidWorkingHoursResolveToDefaults(_ hours: WorkingHours) throws {
        let (store, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        store.save(
            ScheduleConfiguration(includedCalendarIDs: [], workingHours: hours)
        )

        let configuration = store.configuration(visibleCalendarIDs: [])

        #expect(configuration.workingHours == WorkingHours())
        #expect(defaults.integer(forKey: "workingStartHour") == hours.startHour)
    }

    private func makeStore() throws -> (ScheduleConfigurationStore, UserDefaults, String) {
        let suiteName = "ScheduleConfigurationStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        return (ScheduleConfigurationStore(defaults: defaults), defaults, suiteName)
    }
}
