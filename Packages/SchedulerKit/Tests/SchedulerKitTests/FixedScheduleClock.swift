import Foundation

@testable import SchedulerKit
struct FixedScheduleClock: ScheduleClock {
    let now: Date
}
