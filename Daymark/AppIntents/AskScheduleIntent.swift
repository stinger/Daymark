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
        let dialogText = response.text.siriSafeText
        let safeResponse = AssistantResponse(
            text: dialogText,
            items: response.items
        )
        Self.logger.info("AskScheduleIntent returning dialog text=\(dialogText, privacy: .public)")
        return .result(
            dialog: "\(dialogText)",
            view: ScheduleResponseSnippetView(response: safeResponse).padding(16)
        )
    }
}

extension String {
    fileprivate var siriSafeText: String {
        replacingOccurrences(of: "[", with: "(")
            .replacingOccurrences(of: "]", with: ")")
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
