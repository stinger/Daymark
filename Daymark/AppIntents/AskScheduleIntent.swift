import AppIntents
import AssistantKit
import Foundation
import OSLog
import SwiftUI

struct AskScheduleIntent: AppIntent {
    private static let logger = Logger(
        subsystem: "com.example.Daymark",
        category: "AskScheduleIntent"
    )
    static let title: LocalizedStringResource = "Ask About My Schedule"
    static let description = IntentDescription("Ask Daymark a calendar question.")
    static var supportedModes: IntentModes { .background }

    @Parameter(
        title: "Request",
        description: "A question about your schedule",
        requestValueDialog: IntentDialog("How can I help?")
    )
    var request: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        Self.logger.info("AskScheduleIntent perform started")
        Self.logger.info("AskScheduleIntent request=\(request, privacy: .public)")
        let response = await ScheduleIntentAnswerer.answer(request)
        Self.logger.info(
            "AskScheduleIntent response text=\(response.text, privacy: .public) itemCount=\(response.items.count)"
        )
        Self.logger.info("AskScheduleIntent returning dialog text=\(response.spokenText, privacy: .public)")
        return .result(
            dialog: "\(response.spokenText)",
            view: ScheduleResponseSnippetView(response: response).padding(16)
        )
    }
}

@MainActor
enum ScheduleIntentAnswerer {
    static func answer(_ request: String) async -> AssistantResponse {
        let provider = EventKitCalendarProvider()
        let answerer = ScheduleAnswerer(
            calendarAccess: provider,
            configurationStore: ScheduleConfigurationStore(),
            assistantService: FoundationModelAssistantService(provider: provider)
        )

        switch await answerer.answer(request) {
        case .answered(let response):
            return response
        case .calendarAccessUnavailable:
            return AssistantResponse(
                text: DaymarkError.calendarAccessRequired.localizedDescription
            )
        case .assistantUnavailable(let diagnostic):
            return AssistantResponse(
                text: "\(diagnostic) Open Daymark for setup details."
            )
        case .invalidQuestion, .failed:
            return AssistantResponse(
                text: "I couldn't check your schedule. Open Daymark for setup details."
            )
        }
    }
}
