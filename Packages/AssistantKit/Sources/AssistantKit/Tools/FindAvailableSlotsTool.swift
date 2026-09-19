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
            "findAvailableSlots request date=\(arguments.date, privacy: .public) period=\(String(describing: arguments.period), privacy: .public) customStart=\(arguments.customStart ?? "nil", privacy: .public) customEnd=\(arguments.customEnd ?? "nil", privacy: .public) durationMinutes=\(arguments.durationMinutes) firstOnly=\(arguments.firstOnly)"
        )
        guard let interval = searchInterval(for: arguments) else {
            Self.logger.error(
                "findAvailableSlots rejected date=\(arguments.date, privacy: .public) period=\(String(describing: arguments.period), privacy: .public); expected a valid local date and increasing same-day custom bounds"
            )
            throw CalendarToolError.invalidDate
        }
        let start = interval.start
        let end = interval.end

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
            summary =
                "No \(arguments.durationMinutes)-minute opening between \(intervalFormatter.string(from: start)) and \(intervalFormatter.string(from: end))."
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

    private func searchInterval(for arguments: FindAvailableSlotsArguments) -> DateInterval? {
        guard
            let date = ScheduleFormatters.localDay(calendar: calendar).date(from: arguments.date),
            let workingInterval = try? schedulingService.workingInterval(on: date)
        else { return nil }

        switch arguments.period {
        case .workingDay:
            return workingInterval
        case .morning:
            guard let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) else {
                return nil
            }
            let end = min(noon, workingInterval.end)
            return workingInterval.start < end
                ? DateInterval(start: workingInterval.start, end: end) : nil
        case .afternoon:
            guard let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) else {
                return nil
            }
            let start = max(noon, workingInterval.start)
            return start < workingInterval.end
                ? DateInterval(start: start, end: workingInterval.end) : nil
        case .custom:
            guard
                let customStart = arguments.customStart,
                let customEnd = arguments.customEnd,
                let start = ScheduleFormatters.modelDate(customStart, calendar: calendar),
                let end = ScheduleFormatters.modelDate(customEnd, calendar: calendar),
                start < end,
                calendar.isDate(start, inSameDayAs: date),
                calendar.isDate(end.addingTimeInterval(-1), inSameDayAs: date)
            else { return nil }
            return DateInterval(start: start, end: end)
        }
    }

}
