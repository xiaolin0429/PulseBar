import OSLog

enum PulseBarLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.pulsebar.PulseBar"

    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
    static let sampling = Logger(subsystem: subsystem, category: "sampling")
    static let cpu = Logger(subsystem: subsystem, category: "cpu")
    static let memory = Logger(subsystem: subsystem, category: "memory")
    static let disk = Logger(subsystem: subsystem, category: "disk")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let settings = Logger(subsystem: subsystem, category: "settings")
}
