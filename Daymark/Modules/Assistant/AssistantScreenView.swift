import AppIntents
import SwiftUI

struct AssistantScreenView: View {
    @Bindable var viewModel: MainScreenViewModel

    var body: some View {
        NavigationStack {
            List {
                SiriTipView(intent: AskScheduleIntent())

                if #available(iOS 27.0, *) {
                    SiriTipView(intent: SummarizeSelectedEventsIntent())
                }

                Section("Try the assistant") {
                    TextField(
                        "Ask about your schedule",
                        text: $viewModel.assistantRequest,
                        axis: .vertical
                    )
                    .lineLimit(1 ... 5)
                    .submitLabel(.send)
                    .onSubmit {
                        Task {
                            await viewModel.submitAssistantRequest()
                        }
                    }
                }

                Section("Response") {
                    if viewModel.isAnswering {
                        ProgressView("Thinking on device…")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }

                    if let assistantResponse = viewModel.assistantResponse {
                        Text(formattedResponse(assistantResponse.text))
                            .textSelection(.enabled)

                        ScheduleResponseSnippetView(response: assistantResponse)
                    }

                    if viewModel.authorizationState != .fullAccess {
                        Text(
                            "Grant full calendar access in the Status tab before testing requests."
                        )
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Assistant")
            .refreshable {
                await viewModel.load()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Ask Daymark", systemImage: "sparkles") {
                        Task {
                            await viewModel.submitAssistantRequest()
                        }
                    }
                    .disabled(!viewModel.canSubmitAssistantRequest)
                }
            }
        }
    }

    private func formattedResponse(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}
