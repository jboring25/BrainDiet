import OSLog

// MARK: - Logging
//
// House rule: never `print()` in production. Use these category loggers.

enum Log {
    private static let subsystem = "com.jackboring.BrainDiet"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let onboarding = Logger(subsystem: subsystem, category: "onboarding")
}
