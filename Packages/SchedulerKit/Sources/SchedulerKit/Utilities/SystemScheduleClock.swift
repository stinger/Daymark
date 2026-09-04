import Foundation

public struct SystemScheduleClock: ScheduleClock {
    public init() {}

    public var now: Date { Date() }
}
