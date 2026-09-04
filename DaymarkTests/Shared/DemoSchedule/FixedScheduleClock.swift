import Foundation

import SchedulerKit
struct FixedScheduleClock: ScheduleClock {
    let now: Date
}
