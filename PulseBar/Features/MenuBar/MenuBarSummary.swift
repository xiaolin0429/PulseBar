import Foundation

struct MenuBarSummary: Equatable, Sendable {
    var cpuPercent: Double?
    var memoryPercent: Double?
    var diskFreeBytes: UInt64?
    var downloadBytesPerSecond: Double?
    var uploadBytesPerSecond: Double?
    var severity: Severity

    enum Severity: Int, Sendable {
        case normal
        case warning
        case critical
    }

    /// 创建仅含菜单栏必需数值和告警等级的摘要，供预览或占位使用。
    init(
        cpuPercent: Double?,
        memoryPercent: Double?,
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

    /// 从系统快照提取轻量摘要，比例转为百分数，并根据内存压力及磁盘余量定级。
    /// 允许使用短期 stale 值，但不携带完整历史、卷列表或单核数据。
    init(snapshot: SystemSnapshot) {
        let cpu = snapshot.cpu.availableValue
        let memory = snapshot.memory.availableValue
        let disk = snapshot.disk.availableValue?.primaryVolume
        let network = snapshot.network.availableValue
        cpuPercent = cpu.map { $0.totalUsageRatio * 100 }
        memoryPercent = memory.map { $0.usageRatio * 100 }
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
