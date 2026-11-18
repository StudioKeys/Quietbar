import os

extension Logger {
    public static let subsystem = "dev.studiokeys.quietbar"

    public static func quietbar(_ category: String) -> Logger {
        Logger(subsystem: subsystem, category: category)
    }
}
