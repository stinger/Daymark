public enum SchedulingServiceError: Error, Equatable {
    case intervalTooLarge
    case invalidDuration
    case invalidLocalDate
    case invalidWorkingHours
}
