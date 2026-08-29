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

    init(
        cpuPercent: Int?,
        memoryPercent: Int?,
        diskFreeBytes: UInt64?,
        downloadBytesPerSecond: Double?,
        uploadBytesPerSecond: Double?,
        severity: Severity
    ) {
        self.cpuPercent = cpuPercent
        self.memoryPercent = memoryPercent
        self.diskFreeBytes = diskFreeBytes
        self.downloadBytesPerSecond = downloadBytesPerSecond
        self.uploadBytesPerSecond = uploadBytesPerSecond
        self.severity = severity
    }

    static let preview = MenuBarSummary(
        cpuPercent: 18,
        memoryPercent: 62,
        diskFreeBytes: 42 * 1_000_000_000,
        downloadBytesPerSecond: 1_800_000,
        uploadBytesPerSecond: 128_000,
        severity: .normal
    )

    static let unavailable = MenuBarSummary(
        cpuPercent: nil,
        memoryPercent: nil,
        diskFreeBytes: nil,
        downloadBytesPerSecond: nil,
        uploadBytesPerSecond: nil,
        severity: .normal
    )

    init(snapshot: SystemSnapshot) {
        let cpu = snapshot.cpu.availableValue
        let memory = snapshot.memory.availableValue
        let disk = snapshot.disk.availableValue?.primaryVolume
        let network = snapshot.network.availableValue
        cpuPercent = cpu.map { Int(($0.totalUsageRatio * 100).rounded()) }
        memoryPercent = memory.map { Int(($0.usageRatio * 100).rounded()) }
        diskFreeBytes = disk?.availableCapacityBytes
        downloadBytesPerSecond = network?.downloadBytesPerSecond
        uploadBytesPerSecond = network?.uploadBytesPerSecond

        if memory?.pressure == .critical {
            severity = .critical
        } else if memory?.pressure == .warning || (disk?.usageRatio ?? 0) >= 0.9 {
            severity = .warning
        } else {
            severity = .normal
        }
    }
}
