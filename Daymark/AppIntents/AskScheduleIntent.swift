import AppIntents
import AssistantKit

struct AskScheduleIntent: AppIntent {
    static let title: LocalizedStringResource = "Ask About My Schedule"
    static let description = IntentDescription("Ask Daymark a calendar question.")
    static let openAppWhenRun = false

    @Parameter(
        title: "Request",
        description: "A question about your schedule",
        requestValueDialog: IntentDialog("How can I help?")
    )
    var request: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let response = await authorizedScheduleResponse()
        return .result(
            dialog: "\(response.text)",
            view: ScheduleResponseSnippetView(response: response)
        )
    }

    @MainActor
    private func authorizedScheduleResponse() async -> AssistantResponse {
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
