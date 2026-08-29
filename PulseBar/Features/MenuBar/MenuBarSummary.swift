import Foundation

struct MenuBarSummary: Equatable, Sendable {
    var cpuPercent: Int?
    var memoryPercent: Int?
    var diskFreeBytes: UInt64?
    var downloadBytesPerSecond: Double?
    var uploadBytesPerSecond: Double?
    var severity: Severity

    enum Severity: Int, Sendable {
        case normal
        case warning
        case critical
    }

    static let preview = MenuBarSummary(
        cpuPercent: 18,
        memoryPercent: 62,
        diskFreeBytes: 42 * 1_000_000_000,
        downloadBytesPerSecond: 1_800_000,
        uploadBytesPerSecond: 128_000,
        severity: .normal
    )
}
