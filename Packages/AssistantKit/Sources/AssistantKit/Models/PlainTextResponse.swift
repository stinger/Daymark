import FoundationModels

@Generable
struct PlainTextResponse {
    @Guide(description: "One or two short spoken sentences without Markdown formatting")
    let text: String
}
