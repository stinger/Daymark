import Foundation
import FoundationModels
import OSLog
import SchedulerKit

@MainActor
public final class FoundationModelAssistantService: DaymarkServicing {
    private static let logger = Logger(
        subsystem: "com.example.Daymark",
        category: "FoundationModels"
    )

    private let provider: any CalendarEventProvider
    private let model: SystemLanguageModel
    private let clock: any ScheduleClock
    private let calendar: Calendar
    private var readySession: LanguageModelSession?
    private var readyResultStore: AssistantToolResultStore?
    private var readyCalendarIDs: Set<String>?
    private var readyWorkingHours: WorkingHours?

    public init(
        provider: any CalendarEventProvider,
        model: SystemLanguageModel = .default,
        clock: any ScheduleClock = SystemScheduleClock(),
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.provider = provider
        self.model = model
        self.clock = clock
        self.calendar = calendar
    }

    public var isAvailable: Bool {
        model.availability == .available
    }

    public var availabilityDescription: String {
        model.daymarkAvailabilityDescription
    }

    public func prewarm(
        includedCalendarIDs: Set<String>,
        workingHours: WorkingHours
    ) {
        guard model.availability == .available else {
            readySession = nil
            readyResultStore = nil
            readyCalendarIDs = nil
            readyWorkingHours = nil
            return
        }
        if readySession != nil,
            readyResultStore != nil,
            readyCalendarIDs == includedCalendarIDs,
            readyWorkingHours == workingHours
        {
            return
        }

        let (session, resultStore) = makeSession(
            includedCalendarIDs: includedCalendarIDs,
            workingHours: workingHours
        )
        session.prewarm()
        readySession = session
        readyResultStore = resultStore
        readyCalendarIDs = includedCalendarIDs
        readyWorkingHours = workingHours
    }

    public func answer(
        _ request: String,
        includedCalendarIDs: Set<String>,
        workingHours: WorkingHours
    ) async throws -> AssistantResponse {
        guard model.availability == .available else {
            throw DaymarkError.modelUnavailable(model.daymarkAvailabilityDescription)
        }

        let session: LanguageModelSession
        let resultStore: AssistantToolResultStore
        if readyCalendarIDs == includedCalendarIDs,
            readyWorkingHours == workingHours,
            let readySession,
            let readyResultStore
        {
            session = readySession
            resultStore = readyResultStore
        } else {
            (session, resultStore) = makeSession(
                includedCalendarIDs: includedCalendarIDs,
                workingHours: workingHours
            )
        }
        self.readySession = nil
        self.readyResultStore = nil
        readyCalendarIDs = nil
        readyWorkingHours = nil
        defer {
            if readySession == nil {
                prewarm(
                    includedCalendarIDs: includedCalendarIDs,
                    workingHours: workingHours
                )
            }
        }

        do {
            let response = try await session.respond(
                to: prompt(for: request, workingHours: workingHours),
                generating: PlainTextResponse.self
                    // options: GenerationOptions(temperature: 0.01)
            )
            let text = response.content.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let spokenText = response.content.spokenText.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            let items = await resultStore.recordedItems()
            Self.logger.info(
                "Foundation Models response text=\(text, privacy: .public) spokenText=\(spokenText, privacy: .public) itemCount=\(items.count)"
            )
            return AssistantResponse(text: text, spokenText: spokenText, items: items)
        } catch CalendarEventProviderError.accessRequired {
            throw DaymarkError.calendarAccessRequired
        } catch {
            Self.logger.error(
                "Foundation Models request failed: \(String(reflecting: error), privacy: .public)"
            )
            throw error
        }
    }

    private func makeSession(
        includedCalendarIDs: Set<String>,
        workingHours: WorkingHours
    ) -> (LanguageModelSession, AssistantToolResultStore) {
        let schedulingService = SchedulingService(
            provider: provider,
            includedCalendarIDs: includedCalendarIDs,
            workingHours: workingHours,
            clock: clock,
            calendar: calendar
        )
        let resultStore = AssistantToolResultStore()
        let tools: [any Tool] = [
            GetEventsTool(
                schedulingService: schedulingService,
                resultStore: resultStore,
                calendar: calendar
            ),
            FindAvailableSlotsTool(
                schedulingService: schedulingService,
                resultStore: resultStore,
                calendar: calendar
            ),
        ]
        let session = LanguageModelSession(
            model: model,
            tools: tools,
            instructions: instructions
        )
        return (session, resultStore)
    }

    private var instructions: String {
        """
        You are Daymark. You are a helpful assitant that answers questions about the user's calendar schedule. Answer only calendar questions by calling the provided read-only tools.

        First classify the request, then call exactly one tool. Tool selection has priority over all date and time interpretation:
        1. If the user says availability, available, free, open, opening, or slot, use findAvailableSlots. Never use getEvents to answer these requests or infer availability from events.
        2. Otherwise, if the user asks for a schedule, agenda, events, appointments, meetings, calls, busy time, occupied time, or plans, use getEvents. A schedule is a list of events; it is not availability.

        Examples:
        - "What is my availability tomorrow morning?" -> findAvailableSlots with tomorrow's YYYY-MM-DD date, period=morning, no custom bounds, durationMinutes=30, firstOnly=false.
        - "What is my availability tomorrow afternoon?" -> findAvailableSlots with tomorrow's YYYY-MM-DD date, period=afternoon, no custom bounds, durationMinutes=30, firstOnly=false.
        - "What is my schedule tomorrow afternoon?" -> getEvents with tomorrow at 12:00 through the configured working-hours end, callsOnly=false, firstOnly=false.
        - "What was my schedule today?" -> getEvents from today's working-hours interval start through today's working-hours interval end, callsOnly=false, firstOnly=false.

        For getEvents, set callsOnly=true only when the user explicitly asks for calls or meetings. Set firstOnly=true only when the user explicitly asks for the first, earliest, or next event. Otherwise always set firstOnly=false. Past tense does not mean firstOnly and must not exclude events earlier than the current time.

        Resolve time bounds in the user's local time zone. For getEvents with a date but no explicit time, start MUST equal that date's supplied working-hours interval start and end MUST equal that interval's end. Never use the current local time as the start. The words "was" and "today" do not change these bounds. For morning, use the configured working-hours start through 12:00. For afternoon, use 12:00 through the configured working-hours end. Pass bounds as ISO 8601 timestamps with the correct offset for the requested date. Copy supplied interval timestamps exactly when they apply; do not derive replacements. If no date is specified, use the current local date supplied with the request. Event results are already filtered, sorted, and expressed in local time; report their times exactly without converting them.

        For findAvailableSlots, pass the local YYYY-MM-DD date and use period=morning, afternoon, or workingDay whenever one applies. Use period=custom only when the user gives explicit bounds such as "after", "from", or "between", and then supply increasing ISO 8601 customStart and customEnd timestamps. Omit custom bounds for every non-custom period. Default omitted duration to 30 minutes. Set firstOnly=true only when the user explicitly asks for the first, earliest, or next available time; otherwise set it to false. Openings have exact duration and chronological order. Report them exactly, and never merge separate openings into one range.
        Keep the final answer to one short spoken sentence. State the duration and result time for availability. For no result, state the date, working-hour bounds, and duration. Report the first availability slot only.
        When there are multiple events to report - report only their count.
        Never claim to create, edit, or delete calendar data.
        Return plain text only. DO NOT use Markdown, lists, headings, tables, emphasis, or code formatting.
        When there are multiple events or availability slots to report - just state their count. Write as if you are responding to the user. Never state "My", "I" or "We".
        """
    }

    private func prompt(for request: String, workingHours: WorkingHours) -> String {
        let now = clock.now
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        return """
            Current local date: \(localDate(for: now))
            Current local time: \(now.formatted(date: .omitted, time: .standard))
            Time zone: \(calendar.timeZone.identifier)
            Current UTC offset: \(timeZoneOffset(for: now))
            Working hours: \(workingHoursDescription(workingHours))
            Today's working-hours interval: \(workingHoursInterval(for: now, workingHours: workingHours))
            Tomorrow's working-hours interval: \(workingHoursInterval(for: tomorrow, workingHours: workingHours))

            User request:
            \(request)
            """
    }

    private func workingHoursInterval(
        for date: Date,
        workingHours: WorkingHours
    ) -> String {
        guard let interval = try? workingHours.interval(on: date, calendar: calendar) else {
            return "unavailable"
        }

        let formatter = ScheduleFormatters.iso8601(timeZone: calendar.timeZone)
        return
            "\(formatter.string(from: interval.start)) to \(formatter.string(from: interval.end))"
    }

    private func localDate(for date: Date) -> String {
        ScheduleFormatters.localDay(calendar: calendar).string(from: date)
    }

    private func timeZoneOffset(for date: Date) -> String {
        let seconds = calendar.timeZone.secondsFromGMT(for: date)
        let sign = seconds < 0 ? "-" : "+"
        let magnitude = abs(seconds)
        return String(format: "%@%02d:%02d", sign, magnitude / 3_600, magnitude % 3_600 / 60)
    }

    private func workingHoursDescription(_ workingHours: WorkingHours) -> String {
        String(
            format: "%02d:%02d–%02d:%02d",
            workingHours.startHour,
            workingHours.startMinute,
            workingHours.endHour,
            workingHours.endMinute
        )
    }
}
