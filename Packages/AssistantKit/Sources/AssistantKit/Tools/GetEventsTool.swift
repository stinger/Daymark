import Foundation
import FoundationModels
import OSLog
import SchedulerKit

struct GetEventsTool: Tool {
    private static let logger = Logger(
        subsystem: "com.example.Daymark",
        category: "EventsTool"
    )
    let name = "getEvents"
    let description =
        "Gets minimal read-only calendar event data in a bounded ISO 8601 interval."

    private let schedulingService: SchedulingService
    private let resultStore: AssistantToolResultStore
    private let calendar: Calendar

    init(
        schedulingService: SchedulingService,
        resultStore: AssistantToolResultStore = AssistantToolResultStore(),
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.schedulingService = schedulingService
        self.resultStore = resultStore
        self.calendar = calendar
    }

    func call(arguments: GetEventsArguments) async throws -> GetEventsOutput {
        Self.logger.info(
            "getEvents request start=\(arguments.start, privacy: .public) end=\(arguments.end, privacy: .public) callsOnly=\(arguments.callsOnly) firstOnly=\(arguments.firstOnly)"
        )

        guard
            let start = ScheduleFormatters.modelDate(arguments.start, calendar: calendar),
            let end = ScheduleFormatters.modelDate(arguments.end, calendar: calendar),
            start < end
        else {
            Self.logger.error(
                "getEvents rejected start=\(arguments.start, privacy: .public) end=\(arguments.end, privacy: .public); expected an increasing ISO 8601 timestamp interval"
            )
            throw CalendarToolError.invalidDate
        }
        let events = try await schedulingService.events(
            in: DateInterval(start: start, end: end),
            callsOnly: arguments.callsOnly,
            firstOnly: arguments.firstOnly
        )
        Self.logger.info("getEvents returnedEventCount=\(events.count)")
        await resultStore.record(events: events)

        let outputFormatter = ScheduleFormatters.iso8601(timeZone: calendar.timeZone)
        let generatedEvents = events.map { event in
            GeneratedCalendarEvent(
                id: event.id,
                title: event.title,
                start: outputFormatter.string(from: event.start),
                end: outputFormatter.string(from: event.end),
                location: event.location,
                conferencingURL: event.conferencingURL?.absoluteString,
                classifiedAsCall: schedulingService.isCall(event)
            )
        }
        let summary =
            events.isEmpty
            ? "No matching events from \(arguments.start) to \(arguments.end)."
            : "Found \(events.count) matching event(s) in \(calendar.timeZone.identifier)."
        return GetEventsOutput(summary: summary, events: generatedEvents)
    }

}
