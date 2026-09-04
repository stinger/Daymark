import AssistantKit
import Foundation
import SchedulerKit
import Testing

@testable import Daymark

@MainActor
struct MainScreenViewModelTests {
    @Test
    func loadsVisibleCalendarsSelectedByDefaultAndAllowsDeselection() async throws {
        let work = CalendarDescriptor(id: "work", title: "Work")
        let personal = CalendarDescriptor(id: "personal", title: "Personal")
        let provider = FakeCalendarAccessProvider(
            state: .fullAccess,
            calendars: [work, personal]
        )
        let answerer = FakeScheduleAnswerer()
        let viewModel = MainScreenViewModel(
            calendarAccess: provider,
            demoStore: InMemoryDemoEventStore(),
            scheduleAnswerer: answerer,
            configurationStore: makeConfigurationStore(),
            configurationPrewarmDelay: .milliseconds(30)
        )

        await viewModel.load()

        #expect(viewModel.authorizationState == .fullAccess)
        #expect(viewModel.calendars == [work, personal])
        #expect(viewModel[calendar: work.id])
        #expect(viewModel[calendar: personal.id])
        #expect(answerer.prewarmedCalendarIDs == [work.id, personal.id])
        #expect(answerer.prewarmedWorkingHours == WorkingHours())

        viewModel[calendar: personal.id] = false
        viewModel[calendar: work.id] = false
        try await Task.sleep(for: .milliseconds(50))

        #expect(viewModel[calendar: personal.id] == false)
        #expect(viewModel[calendar: work.id] == false)
        #expect(viewModel.workingHours == WorkingHours())
        #expect(answerer.prewarmCount == 2)
        #expect(answerer.prewarmedCalendarIDs == [])
    }

    @Test
    func debouncesWorkingHoursPrewarming() async throws {
        let answerer = FakeScheduleAnswerer()
        let viewModel = MainScreenViewModel(
            calendarAccess: FakeCalendarAccessProvider(state: .notDetermined),
            demoStore: InMemoryDemoEventStore(),
            scheduleAnswerer: answerer,
            configurationStore: makeConfigurationStore(),
            configurationPrewarmDelay: .milliseconds(30)
        )
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: Date())
        let eight = try #require(calendar.date(bySettingHour: 8, minute: 0, second: 0, of: today))
        let ten = try #require(calendar.date(bySettingHour: 10, minute: 0, second: 0, of: today))

        viewModel.workingDayStartsAt = eight
        viewModel.workingDayStartsAt = ten
        try await Task.sleep(for: .milliseconds(50))

        #expect(answerer.prewarmCount == 1)
        #expect(answerer.prewarmedWorkingHours?.startHour == 10)
    }

    @Test
    func requestingAccessRefreshesAuthorizationAndCalendars() async {
        let calendar = CalendarDescriptor(id: "work", title: "Work")
        let provider = FakeCalendarAccessProvider(
            state: .notDetermined,
            calendars: [calendar]
        )
        let viewModel = MainScreenViewModel(
            calendarAccess: provider,
            demoStore: InMemoryDemoEventStore(),
            scheduleAnswerer: FakeScheduleAnswerer(),
            configurationStore: makeConfigurationStore()
        )

        await viewModel.requestCalendarAccess()

        #expect(viewModel.authorizationState == .fullAccess)
        #expect(viewModel.calendars == [calendar])
    }

    @Test
    func textRequestPresentsScheduleAnswer() async {
        let answerer = FakeScheduleAnswerer(
            outcome: .answered(
                AssistantResponse(text: "Your first 30-minute opening is 9:30 AM.")
            )
        )
        let viewModel = MainScreenViewModel(
            calendarAccess: FakeCalendarAccessProvider(state: .fullAccess),
            demoStore: InMemoryDemoEventStore(),
            scheduleAnswerer: answerer,
            configurationStore: makeConfigurationStore()
        )
        viewModel.assistantRequest = "When am I free?"

        await viewModel.submitAssistantRequest()

        #expect(
            viewModel.assistantResponse
                == AssistantResponse(text: "Your first 30-minute opening is 9:30 AM.")
        )
        #expect(answerer.receivedQuestion == "When am I free?")
    }

    @Test
    func creatingDemoScheduleReportsOnlyCreatedEvents() async {
        let viewModel = MainScreenViewModel(
            calendarAccess: FakeCalendarAccessProvider(state: .fullAccess),
            demoStore: InMemoryDemoEventStore(),
            scheduleAnswerer: FakeScheduleAnswerer(),
            configurationStore: makeConfigurationStore()
        )

        await viewModel.createDemoSchedule()

        #expect(viewModel.demoStatus == "Created 4 demo events.")
    }

    @Test("Text entry requests setup when access is revoked during a query")
    func textRequestReportsAuthorizationLossAfterReadinessCheck() async {
        let provider = FakeCalendarAccessProvider(state: .fullAccess)
        let viewModel = MainScreenViewModel(
            calendarAccess: provider,
            demoStore: InMemoryDemoEventStore(),
            scheduleAnswerer: FakeScheduleAnswerer(
                outcome: .calendarAccessUnavailable(.restricted)
            ),
            configurationStore: makeConfigurationStore()
        )
        viewModel.assistantRequest = "When am I free?"

        await viewModel.submitAssistantRequest()

        #expect(viewModel.authorizationState == .restricted)
        #expect(viewModel.calendars.isEmpty)
        #expect(
            viewModel.assistantResponse
                == AssistantResponse(
                    text:
                        "Open Daymark and grant full calendar access before asking about your schedule."
                )
        )
    }

    private func makeConfigurationStore() -> ScheduleConfigurationStore {
        let suiteName = "MainScreenViewModelTests.\(UUID().uuidString)"
        return ScheduleConfigurationStore(defaults: UserDefaults(suiteName: suiteName)!)
    }
}
