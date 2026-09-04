import Foundation

public protocol ScheduleClock: Sendable {
    var now: Date { get }
}
