@testable import Daymark

actor FakeCalendarAccessProvider: CalendarAccessProviding {
    private var state: CalendarAuthorizationState
    private let calendars: [CalendarDescriptor]

    init(
        state: CalendarAuthorizationState,
        calendars: [CalendarDescriptor] = []
    ) {
        self.state = state
        self.calendars = calendars
    }

    func authorizationState() -> CalendarAuthorizationState {
        state
    }

    func requestFullAccess() -> Bool {
        state = .fullAccess
        return true
    }

    func setAuthorizationState(_ state: CalendarAuthorizationState) {
        self.state = state
    }

    func availableCalendars() -> [CalendarDescriptor] {
        calendars
    }
}
