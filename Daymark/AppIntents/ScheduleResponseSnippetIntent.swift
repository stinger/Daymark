import AppIntents
import AssistantKit
import Foundation
import SwiftUI

struct ScheduleResponseSnippetIntent: SnippetIntent {
    static let title: LocalizedStringResource = "Schedule Response"

    @Parameter(title: "Original Request") var request: String
    @Parameter(title: "Response") var responseText: String
    @Parameter(title: "Item Titles") var itemTitles: [String]
    @Parameter(title: "Item Starts") var itemStarts: [Date]
    @Parameter(title: "Item Ends") var itemEnds: [Date]
    @Parameter(title: "Availability Items") var availabilityItems: [Bool]

    init() {}

    init(request: String, response: AssistantResponse) {
        self.request = request
        responseText = response.text
        let items = response.items.map(ScheduleTimelineItem.init)
        itemTitles = items.map(\.title)
        itemStarts = items.map(\.interval.start)
        itemEnds = items.map(\.interval.end)
        availabilityItems = items.map(\.isAvailability)
    }

    @available(iOS 27.0, *)
    init(request: String, responseText: String, events: [CalendarEventEntity]) {
        self.request = request
        self.responseText = responseText
        itemTitles = events.map(\.title)
        itemStarts = events.map(\.start)
        itemEnds = events.map(\.end)
        availabilityItems = Array(repeating: false, count: events.count)
    }

    func perform() async throws -> some IntentResult & ShowsSnippetView {
        .result(
            view: InteractiveScheduleResponseSnippetView(
                responseText: responseText,
                items: items,
                refreshIntent: RefreshScheduleSnippetIntent(request: request)
            )
        )
    }

    private var items: [ScheduleTimelineItem] {
        itemTitles.indices.compactMap { index in
            guard itemStarts.indices.contains(index),
                itemEnds.indices.contains(index),
                availabilityItems.indices.contains(index)
            else {
                return nil
            }
            return ScheduleTimelineItem(
                title: itemTitles[index],
                start: itemStarts[index],
                end: itemEnds[index],
                isAvailability: availabilityItems[index]
            )
        }
    }
}

struct RefreshScheduleSnippetIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh Schedule"

    @Parameter(title: "Original Request") var request: String

    init() {}

    init(request: String) {
        self.request = request
    }

    @MainActor
    func perform() async throws -> some IntentResult & ShowsSnippetIntent {
        let response = await ScheduleIntentAnswerer.answer(request)
        return .result(
            snippetIntent: ScheduleResponseSnippetIntent(request: request, response: response))
    }
}

private struct InteractiveScheduleResponseSnippetView: View {
    let responseText: String
    let items: [ScheduleTimelineItem]
    let refreshIntent: RefreshScheduleSnippetIntent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScheduleResponseSnippetView(items: items)
            Button(intent: refreshIntent) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
    }
}
