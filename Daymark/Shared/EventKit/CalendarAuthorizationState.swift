enum CalendarAuthorizationState: Sendable, Equatable {
    case notDetermined
    case denied
    case restricted
    case writeOnly
    case fullAccess
}
