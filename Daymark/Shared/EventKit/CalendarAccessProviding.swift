protocol CalendarAccessProviding: Sendable {
    func authorizationState() async -> CalendarAuthorizationState
    func requestFullAccess() async throws -> Bool
    func availableCalendars() async -> [CalendarDescriptor]
}
