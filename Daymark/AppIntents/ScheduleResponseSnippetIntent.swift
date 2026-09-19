import AppIntents
import AssistantKit
import Foundation
import OSLog
import SwiftUI

struct ScheduleResponseSnippetIntent: SnippetIntent {
    private static let logger = Logger(
        subsystem: "com.example.Daymark",
        category: "ScheduleResponseSnippetIntent"
    )
    static let title: LocalizedStringResource = "Schedule Response"

    @Parameter(title: "Original Request") var request: String
    @Parameter(title: "Response") var responseText: String
    @Parameter(title: "Show Response Text") var showsResponseText: Bool
    @Parameter(title: "Timeline Items") var timelineItems: String

    init() {}

    init(
        request: String,
        response: AssistantResponse,
        showsResponseText: Bool = false
    ) {
        self.request = request
        responseText = response.text
        self.showsResponseText = showsResponseText
        timelineItems = Self.encode(response.items.map(ScheduleTimelineItem.init))
    }

    @available(iOS 27.0, *)
    init(request: String, responseText: String, events: [CalendarEventEntity]) {
        self.request = request
        self.responseText = responseText
        showsResponseText = false
        timelineItems = Self.encode(
            events.map {
                ScheduleTimelineItem(
                    title: $0.title,
                    start: $0.start,
                    end: $0.end,
                    isAvailability: false
                )
            }
        )
    }

    func perform() async throws -> some IntentResult & ShowsSnippetView {
        Self.logger.info(
            "ScheduleResponseSnippetIntent render responseText=\(responseText, privacy: .public) itemCount=\(items.count)"
        )
        return .result(
            view: InteractiveScheduleResponseSnippetView(
                responseText: responseText,
                showsResponseText: showsResponseText,
                items: items,
                refreshIntent: RefreshScheduleSnippetIntent(
                    request: request,
                    showsResponseText: showsResponseText
                )
            )
        )
    }

    private var items: [ScheduleTimelineItem] {
        guard let data = timelineItems.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([ScheduleTimelineItem].self, from: data)) ?? []
    }

    private static func encode(_ items: [ScheduleTimelineItem]) -> String {
        guard
            let data = try? JSONEncoder().encode(items),
            let value = String(data: data, encoding: .utf8)
        else { return "[]" }
        return value
    }
}

struct RefreshScheduleSnippetIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh Schedule"

    @Parameter(title: "Original Request") var request: String
    @Parameter(title: "Show Response Text") var showsResponseText: Bool

    init() {}

    init(request: String, showsResponseText: Bool) {
        self.request = request
        self.showsResponseText = showsResponseText
    }

    @MainActor
    func perform() async throws -> some IntentResult & ShowsSnippetIntent {
        let response = await ScheduleIntentAnswerer.answer(request)
        return .result(
            snippetIntent: ScheduleResponseSnippetIntent(
                request: request,
                response: response,
                showsResponseText: showsResponseText
            )
        )
    }
}

private struct InteractiveScheduleResponseSnippetView: View {
    let responseText: String
    let showsResponseText: Bool
    let items: [ScheduleTimelineItem]
    let refreshIntent: RefreshScheduleSnippetIntent

    @ViewBuilder
    var body: some View {
        if items.isEmpty == false {
            VStack(alignment: .leading, spacing: 12) {
                if showsResponseText {
                    Text(responseText)
                        .font(.headline)
                }

                ScheduleResponseSnippetView(items: items)
                Button(intent: refreshIntent) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}
