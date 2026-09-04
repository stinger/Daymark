import Foundation

struct DemoEventDefinition: Identifiable, Sendable, Equatable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let location: String?
    let ownershipURL: URL
}
