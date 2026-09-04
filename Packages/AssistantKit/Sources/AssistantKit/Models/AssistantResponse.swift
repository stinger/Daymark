public struct AssistantResponse: Sendable, Equatable {
    public let text: String
    public let items: [AssistantPresentationItem]

    public init(text: String, items: [AssistantPresentationItem] = []) {
        self.text = text
        self.items = items
    }
}
