import AssistantKit
import Foundation
import SchedulerKit
import Testing

@testable import Daymark

@MainActor
struct ScheduleAnswererTests {
    @Test
    func forwardsPrewarmingConfiguration() {
        let assistant = FakeDaymarkService()
        let answerer = makeAnswerer(
            calendarAccess: FakeCalendarAccessProvider(state: .fullAccess),
            assistant: assistant
        )
        let workingHours = WorkingHours(startHour: 8, endHour: 16)

        answerer.prewarm(includedCalendarIDs: ["work"], workingHours: workingHours)

        #expect(assistant.prewarmedCalendarIDs == ["work"])
        #expect(assistant.prewarmedWorkingHours == workingHours)
    }

    @Test
    func answersWithTrimmedQuestionAndCurrentConfiguration() async {
        let work = CalendarDescriptor(id: "work", title: "Work")
        let personal = CalendarDescriptor(id: "personal", title: "Personal")
        let calendarAccess = FakeCalendarAccessProvider(
            state: .fullAccess,
            calendars: [work, personal]
        )
        let assistant = FakeDaymarkService(
            response: AssistantResponse(text: "You are free at 9:30 AM.")
        )
        let configurationStore = makeConfigurationStore()
        let hours = WorkingHours(startHour: 9, endHour: 17)
        configurationStore.save(
            ScheduleConfiguration(includedCalendarIDs: [work.id], workingHours: hours)
        )
        let answerer = ScheduleAnswerer(
            calendarAccess: calendarAccess,
            configurationStore: configurationStore,
            assistantService: assistant
        )

        let outcome = await answerer.answer("  When am I free?  ")

        #expect(outcome == .answered(AssistantResponse(text: "You are free at 9:30 AM.")))
        #expect(assistant.receivedRequest == "When am I free?")
        #expect(assistant.receivedCalendarIDs == [work.id])
        #expect(assistant.receivedWorkingHours == hours)
    }

    @Test
    func reportsCalendarAccessBeforeAssistantAvailability() async {
        let assistant = FakeDaymarkService(
            isAvailable: false,
            availabilityDescription: "Model unavailable"
        )
        let answerer = makeAnswerer(
            calendarAccess: FakeCalendarAccessProvider(state: .denied),
            assistant: assistant
        )

        let outcome = await answerer.answer("When am I free?")

        #expect(outcome == .calendarAccessUnavailable(.denied))
        #expect(assistant.receivedRequest == nil)
    }

    @Test
    func reportsAssistantUnavailability() async {
        let answerer = makeAnswerer(
            calendarAccess: FakeCalendarAccessProvider(state: .fullAccess),
            assistant: FakeDaymarkService(
                isAvailable: false,
                availabilityDescription: "Model unavailable"
            )
        )

        let outcome = await answerer.answer("When am I free?")

        #expect(outcome == .assistantUnavailable("Model unavailable"))
    }

    @Test
    func rejectsEmptyQuestion() async {
        let assistant = FakeDaymarkService()
        let answerer = makeAnswerer(
            calendarAccess: FakeCalendarAccessProvider(state: .fullAccess),
            assistant: assistant
        )

        let outcome = await answerer.answer("  \n ")

        #expect(outcome == .invalidQuestion)
        #expect(assistant.receivedRequest == nil)
    }

    @Test
    func refreshesAuthorizationAfterAccessLoss() async {
        let calendarAccess = FakeCalendarAccessProvider(state: .fullAccess)
        let assistant = FakeDaymarkService(
            error: DaymarkError.calendarAccessRequired,
            onAnswer: { await calendarAccess.setAuthorizationState(.restricted) }
        )
        let answerer = makeAnswerer(calendarAccess: calendarAccess, assistant: assistant)

        let outcome = await answerer.answer("When am I free?")

        #expect(outcome == .calendarAccessUnavailable(.restricted))
    }

    @Test
    func hidesImplementationFailure() async {
        let answerer = makeAnswerer(
            calendarAccess: FakeCalendarAccessProvider(state: .fullAccess),
            assistant: FakeDaymarkService(error: CancellationError())
        )

        let outcome = await answerer.answer("When am I free?")

        #expect(outcome == .failed)
    }

    private func makeAnswerer(
        calendarAccess: FakeCalendarAccessProvider,
        assistant: FakeDaymarkService
    ) -> ScheduleAnswerer {
        ScheduleAnswerer(
            calendarAccess: calendarAccess,
            configurationStore: makeConfigurationStore(),
            assistantService: assistant
        )
    }

    private func makeConfigurationStore() -> ScheduleConfigurationStore {
        let suiteName = "ScheduleAnswererTests.\(UUID().uuidString)"
        return ScheduleConfigurationStore(defaults: UserDefaults(suiteName: suiteName)!)
    }
}
