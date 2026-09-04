import AssistantKit
import Foundation
import Observation
import SchedulerKit

@MainActor
@Observable
final class MainScreenViewModel {
    let status = "Ready for Siri"

    private let calendarAccess: any CalendarAccessProviding
    private let demoSchedule: DemoScheduleService
    private let scheduleAnswerer: any ScheduleAnswering
    private let configurationStore: ScheduleConfigurationStore
    private let configurationPrewarmDelay: Duration
    private var configurationPrewarmTask: Task<Void, Never>?
    private var configuration = ScheduleConfiguration(
        includedCalendarIDs: [],
        workingHours: WorkingHours()
    )

    var authorizationState: CalendarAuthorizationState = .notDetermined
    var calendars: [CalendarDescriptor] = []
    var workingDayStartsAt: Date {
        get { date(hour: configuration.workingHours.startHour, minute: configuration.workingHours.startMinute) }
        set {
            let calendar = Calendar.autoupdatingCurrent
            saveWorkingHours(
                WorkingHours(
                    startHour: calendar.component(.hour, from: newValue),
                    startMinute: calendar.component(.minute, from: newValue),
                    endHour: configuration.workingHours.endHour,
                    endMinute: configuration.workingHours.endMinute
                )
            )
        }
    }
    var workingDayEndsAt: Date {
        get { date(hour: configuration.workingHours.endHour, minute: configuration.workingHours.endMinute) }
        set {
            let calendar = Calendar.autoupdatingCurrent
            saveWorkingHours(
                WorkingHours(
                    startHour: configuration.workingHours.startHour,
                    startMinute: configuration.workingHours.startMinute,
                    endHour: calendar.component(.hour, from: newValue),
                    endMinute: calendar.component(.minute, from: newValue)
                )
            )
        }
    }
    var errorMessage: String?
    var demoStatus: String?
    var assistantRequest = ""
    var assistantResponse: AssistantResponse?
    var isLoading = false
    var isAnswering = false

    convenience init() {
        let provider = EventKitCalendarProvider()
        let configurationStore = ScheduleConfigurationStore()
        self.init(
            calendarAccess: provider,
            demoStore: provider,
            scheduleAnswerer: ScheduleAnswerer(
                calendarAccess: provider,
                configurationStore: configurationStore,
                assistantService: FoundationModelAssistantService(provider: provider)
            ),
            configurationStore: configurationStore
        )
    }

    init(
        calendarAccess: any CalendarAccessProviding,
        demoStore: any DemoEventStore,
        scheduleAnswerer: any ScheduleAnswering,
        configurationStore: ScheduleConfigurationStore = ScheduleConfigurationStore(),
        configurationPrewarmDelay: Duration = .seconds(1)
    ) {
        self.calendarAccess = calendarAccess
        demoSchedule = DemoScheduleService(store: demoStore)
        self.scheduleAnswerer = scheduleAnswerer
        self.configurationStore = configurationStore
        self.configurationPrewarmDelay = configurationPrewarmDelay
    }

    var authorizationDescription: String {
        switch authorizationState {
        case .notDetermined:
            "Calendar access has not been requested. Grant access to query your schedule."
        case .denied:
            "Calendar access is denied. Enable full calendar access in Settings."
        case .restricted:
            "Calendar access is restricted on this device."
        case .writeOnly:
            "Write-only access cannot read your schedule. Enable full calendar access in Settings."
        case .fullAccess:
            "Full calendar access is available. Assistant tools remain read-only."
        }
    }

    var canRequestCalendarAccess: Bool {
        authorizationState == .notDetermined
    }

    var modelAvailabilityDescription: String {
        scheduleAnswerer.readiness.diagnostic
    }

    var canSubmitAssistantRequest: Bool {
        authorizationState == .fullAccess
            && scheduleAnswerer.readiness.isAvailable
            && !assistantRequest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isAnswering
            && workingDayStartsAt < workingDayEndsAt
    }

    var includedCalendarIDs: Set<String> {
        configuration.includedCalendarIDs
    }

    var workingHours: WorkingHours {
        configuration.workingHours
    }

    subscript(calendar id: String) -> Bool {
        get { configuration.includedCalendarIDs.contains(id) }
        set {
            var ids = configuration.includedCalendarIDs
            if newValue {
                ids.insert(id)
            } else {
                ids.remove(id)
            }
            configuration = ScheduleConfiguration(
                includedCalendarIDs: ids,
                workingHours: configuration.workingHours
            )
            configurationStore.save(configuration)
            scheduleConfigurationPrewarm()
        }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        authorizationState = await calendarAccess.authorizationState()
        await loadCalendarsIfAuthorized()
    }

    func requestCalendarAccess() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            _ = try await calendarAccess.requestFullAccess()
            authorizationState = await calendarAccess.authorizationState()
            await loadCalendarsIfAuthorized()
        } catch {
            errorMessage = "Calendar access could not be requested: \(error.localizedDescription)"
        }
    }

    func submitAssistantRequest() async {
        isAnswering = true
        assistantResponse = nil
        defer { isAnswering = false }

        switch await scheduleAnswerer.answer(assistantRequest) {
        case .answered(let response):
            assistantResponse = response
        case .calendarAccessUnavailable(let state):
            authorizationState = state
            await loadCalendarsIfAuthorized()
            assistantResponse = AssistantResponse(
                text: DaymarkError.calendarAccessRequired.localizedDescription
            )
        case .assistantUnavailable(let diagnostic):
            assistantResponse = AssistantResponse(text: diagnostic)
        case .invalidQuestion:
            break
        case .failed:
            assistantResponse = AssistantResponse(text: "The assistant could not answer.")
        }
    }

    func createDemoSchedule() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let createdCount = try await demoSchedule.create()
            demoStatus = "Created \(createdCount) demo events."
        } catch {
            errorMessage = "The demo schedule could not be created: \(error.localizedDescription)"
        }
    }

    func removeDemoSchedule() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let removedCount = try await demoSchedule.remove()
            demoStatus = "Removed \(removedCount) Daymark demo events."
        } catch {
            errorMessage = "The demo schedule could not be removed: \(error.localizedDescription)"
        }
    }

    private func loadCalendarsIfAuthorized() async {
        guard authorizationState == .fullAccess else {
            calendars = []
            return
        }

        calendars = await calendarAccess.availableCalendars()
        configuration = configurationStore.configuration(
            visibleCalendarIDs: Set(calendars.map(\.id))
        )
        prewarmAssistant()
    }

    private func prewarmAssistant() {
        scheduleAnswerer.prewarm(
            includedCalendarIDs: configuration.includedCalendarIDs,
            workingHours: configuration.workingHours
        )
    }

    private func saveWorkingHours(_ hours: WorkingHours) {
        configuration = ScheduleConfiguration(
            includedCalendarIDs: configuration.includedCalendarIDs,
            workingHours: hours
        )
        configurationStore.save(configuration)
        scheduleConfigurationPrewarm()
    }

    private func scheduleConfigurationPrewarm() {
        configurationPrewarmTask?.cancel()
        let delay = configurationPrewarmDelay
        configurationPrewarmTask = Task { [weak self] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            self?.prewarmAssistant()
        }
    }

    private func date(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: Date())
        return calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: today
        ) ?? today
    }
}
