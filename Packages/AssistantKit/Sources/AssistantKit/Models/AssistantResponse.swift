public struct AssistantResponse: Sendable, Equatable {
    public let text: String
    public let spokenText: String
    public let items: [AssistantPresentationItem]

    public init(text: String, spokenText: String = "", items: [AssistantPresentationItem] = []) {
        self.text = text
        self.spokenText = spokenText
        self.items = items
    }
}
