import OSLog

extension Logger {
    static func daymark(category: String? = nil) -> Logger {
        Logger(
            subsystem: "com.example.Daymark",
            category: category ?? "General"
        )
    }
}
