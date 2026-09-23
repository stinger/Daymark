import FoundationModels

@Generable
struct PlainTextResponse {
    // swift-format-ignore
    @Guide(description: "One or two short user-facing sentences without Markdown formatting. Hours should be formatted as HH:mm using 24-hour format.")
    let text: String

    // swift-format-ignore
    @Guide(description: "One or two short spoken user-facing sentences with hours formatted so that they feel natural to the user when spoken.")
    let spokenText: String
}
