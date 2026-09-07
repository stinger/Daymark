import Foundation
import FoundationModels
import OSLog
import SchedulerKit

struct FindAvailableSlotsTool: Tool {
    private static let logger = Logger(
        subsystem: "com.example.Daymark",
        category: "AvailabilityTool"
    )
    let name = "findAvailableSlots"
    let description =
        "Finds exact-duration read-only free slots using deterministic calendar arithmetic and configured working hours."

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

    func call(arguments: FindAvailableSlotsArguments) async throws -> FindAvailableSlotsOutput {
        Self.logger.info(
            "findAvailableSlots request start=\(arguments.start, privacy: .public) end=\(arguments.end, privacy: .public) durationMinutes=\(arguments.durationMinutes) firstOnly=\(arguments.firstOnly)"
        )
        guard
            let start = ScheduleFormatters.modelDate(arguments.start, calendar: calendar),
            let end = ScheduleFormatters.modelDate(arguments.end, calendar: calendar),
            start < end,
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: start)),
            end <= dayEnd
        else {
            Self.logger.error(
                "findAvailableSlots rejected start=\(arguments.start, privacy: .public) end=\(arguments.end, privacy: .public); expected an increasing ISO 8601 timestamp interval within one calendar day"
            )
            throw CalendarToolError.invalidDate
        }

        let result = try await schedulingService.findAvailableSlots(
            in: DateInterval(start: start, end: end),
            duration: TimeInterval(arguments.durationMinutes * 60),
            firstOnly: arguments.firstOnly
        )
        let intervalFormatter = ScheduleFormatters.iso8601(timeZone: calendar.timeZone)
        let slots = result.slots.map { slot in
            "\(intervalFormatter.string(from: slot.start))/\(intervalFormatter.string(from: slot.end))"
        }.joined(separator: ",")
        Self.logger.info(
            "findAvailableSlots result slotCount=\(result.slots.count) slots=\(slots, privacy: .public)"
        )

        let timeFormatter = ScheduleFormatters.displayTime(calendar: calendar)

        await resultStore.record(availabilitySlots: result.slots)

        let generatedSlots = result.slots.map { slot in
            GeneratedAvailabilitySlot(
                start: intervalFormatter.string(from: slot.start),
                end: intervalFormatter.string(from: slot.end)
            )
        }
        let summary: String
        if result.slots.isEmpty {
            // swift-format-ignore
            summary = "No \(arguments.durationMinutes)-minute opening between \(arguments.start) and \(arguments.end)."
        } else {
            let openings = result.slots.map { slot in
                "\(timeFormatter.string(from: slot.start))–\(timeFormatter.string(from: slot.end))"
            }.joined(separator: ", ")
            summary =
                arguments.firstOnly
                ? "The earliest exact \(arguments.durationMinutes)-minute opening is \(openings)."
                : "Exact \(arguments.durationMinutes)-minute openings, in chronological order: \(openings)."
        }
        return FindAvailableSlotsOutput(summary: summary, slots: generatedSlots)
    }

}
