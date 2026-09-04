import AssistantKit
import Foundation
import OSLog
import SchedulerKit

@MainActor
struct ScheduleAnswerer: ScheduleAnswering {
    private static let logger = Logger.daymark(category: "ScheduleAnswer")

    private let calendarAccess: any CalendarAccessProviding
    private let configurationStore: ScheduleConfigurationStore
    private let assistantService: any DaymarkServicing

    init(
        calendarAccess: any CalendarAccessProviding,
        configurationStore: ScheduleConfigurationStore,
        assistantService: any DaymarkServicing
    ) {
        self.calendarAccess = calendarAccess
        self.configurationStore = configurationStore
        self.assistantService = assistantService
    }

    var readiness: ScheduleAnswerReadiness {
        ScheduleAnswerReadiness(
            isAvailable: assistantService.isAvailable,
            diagnostic: assistantService.availabilityDescription
        )
    }

    func prewarm(
        includedCalendarIDs: Set<String>,
        workingHours: WorkingHours
    ) {
        assistantService.prewarm(
            includedCalendarIDs: includedCalendarIDs,
            workingHours: workingHours
        )
    }

    func answer(_ question: String) async -> ScheduleAnswerOutcome {
        let question = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard question.isEmpty == false else { return .invalidQuestion }

        let authorizationState = await calendarAccess.authorizationState()
        guard authorizationState == .fullAccess else {
            return .calendarAccessUnavailable(authorizationState)
        }
        guard assistantService.isAvailable else {
            return .assistantUnavailable(assistantService.availabilityDescription)
        }

        let calendars = await calendarAccess.availableCalendars()
        let configuration = configurationStore.configuration(
            visibleCalendarIDs: Set(calendars.map(\.id))
        )

        do {
            return .answered(
                try await assistantService.answer(
                    question,
                    includedCalendarIDs: configuration.includedCalendarIDs,
                    workingHours: configuration.workingHours
                )
            )
        } catch DaymarkError.calendarAccessRequired {
            return .calendarAccessUnavailable(await calendarAccess.authorizationState())
        } catch {
            Self.logger.error(
                "Schedule Answer failed: \(String(reflecting: error), privacy: .public)"
            )
            return .failed
        }
    }
}
