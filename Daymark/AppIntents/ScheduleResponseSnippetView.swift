import AssistantKit
import Foundation
import SwiftUI

struct ScheduleResponseSnippetView: View {
    let response: AssistantResponse

    private let hourHeight: CGFloat = 48
    private let timeColumnWidth: CGFloat = 32

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0 ... hourCount, id: \.self) { hourOffset in
                HStack(alignment: .center, spacing: 8) {
                    Text(hourLabel(hourOffset))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: timeColumnWidth, alignment: .leading)
                        .padding(.leading, 16)

                    Rectangle()
                        .fill(.secondary.opacity(0.2))
                        .frame(height: 1)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 1)
                .offset(y: CGFloat(hourOffset) * hourHeight)
            }

            ForEach(response.items.indices, id: \.self) { index in
                switch response.items[index] {
                case .event(let event):
                    scheduleBlock(
                        title: event.title,
                        interval: DateInterval(start: event.start, end: event.end),
                        color: .blue
                    )
                case .availabilitySlot(let interval):
                    scheduleBlock(title: "Available", interval: interval, color: .green)
                }
            }
        }
        .frame(height: CGFloat(hourCount) * hourHeight, alignment: .top)
        .padding(.vertical, 12)
    }

    private var intervals: [DateInterval] {
        response.items.map { item in
            switch item {
            case .event(let event):
                DateInterval(start: event.start, end: event.end)
            case .availabilitySlot(let interval):
                interval
            }
        }
    }

    private var timelineStart: Date {
        let earliest = intervals.map(\.start).min() ?? Date()
        return Calendar.current.dateInterval(of: .hour, for: earliest)?.start ?? earliest
    }

    private var hourCount: Int {
        let latest = intervals.map(\.end).max() ?? timelineStart.addingTimeInterval(3600)
        let minutes = max(60, latest.timeIntervalSince(timelineStart) / 60)
        return Int(ceil(minutes / 60))
    }

    private func hourLabel(_ offset: Int) -> String {
        timelineStart.addingTimeInterval(Double(offset) * 3600)
            .formatted(.dateTime.hour())
    }

    private func scheduleBlock(title: String, interval: DateInterval, color: Color) -> some View {
        let y = interval.start.timeIntervalSince(timelineStart) / 3600 * hourHeight
        let height = max(20, interval.duration / 3600 * hourHeight - 4)

        return HStack(alignment: .top, spacing: 8) {
            Rectangle()
                .fill(color)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if interval.duration >= 3600 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .imageScale(.small)
                        Text(interval.start ..< interval.end, format: .interval.hour().minute())
                            .font(.caption)
                    }
                }
            }
            .foregroundStyle(color)

            Spacer(minLength: 0)
        }
        .frame(height: height, alignment: .top)
        .background(color.opacity(0.16), in: .rect(cornerRadius: 0))
        .padding(.leading, timeColumnWidth + 24)
        .offset(y: y + 2)
        .accessibilityElement(children: .combine)
    }
}
