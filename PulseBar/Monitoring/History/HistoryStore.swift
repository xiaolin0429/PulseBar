import Foundation

public struct HistoryPoint: Identifiable, Sendable, Equatable {
    public let sequence: UInt64
    public let wallTime: Date
    public let monotonicTime: ContinuousClock.Instant
    public let value: Double

    public var id: UInt64 { sequence }
}

public struct DashboardHistory: Sendable, Equatable {
    public var cpuUsage: [HistoryPoint] = []
    public var memoryUsage: [HistoryPoint] = []
    public var diskRead: [HistoryPoint] = []
    public var diskWrite: [HistoryPoint] = []
    public var networkDownload: [HistoryPoint] = []
    public var networkUpload: [HistoryPoint] = []

    public static let empty = DashboardHistory()
}

public struct HistoryStore: Sendable {
    private var cpu = RingBuffer<HistoryPoint>(capacity: 360)
    private var memory = RingBuffer<HistoryPoint>(capacity: 360)
    private var diskRead = RingBuffer<HistoryPoint>(capacity: 360)
    private var diskWrite = RingBuffer<HistoryPoint>(capacity: 360)
    private var networkDownload = RingBuffer<HistoryPoint>(capacity: 360)
    private var networkUpload = RingBuffer<HistoryPoint>(capacity: 360)

    public init() {}

    /// 把快照中可取出的指标写入环形缓存；预热、不可用和缺失速率不补零。
    /// 这里的 availableValue 也包含 stale 值，因此降级期间可能记录旧值。
    public mutating func append(_ snapshot: SystemSnapshot) {
        if let value = snapshot.cpu.availableValue?.totalUsageRatio {
            cpu.append(point(value, from: snapshot))
        }
        if let value = snapshot.memory.availableValue?.usageRatio {
            memory.append(point(value, from: snapshot))
        }
        if let disk = snapshot.disk.availableValue {
            if let value = disk.aggregateReadBytesPerSecond {
                diskRead.append(point(value, from: snapshot))
            }
            if let value = disk.aggregateWriteBytesPerSecond {
                diskWrite.append(point(value, from: snapshot))
            }
        }
        if let network = snapshot.network.availableValue {
            if let value = network.downloadBytesPerSecond {
                networkDownload.append(point(value, from: snapshot))
            }
            if let value = network.uploadBytesPerSecond {
                networkUpload.append(point(value, from: snapshot))
            }
        }
    }

    /// 按指定时间窗口生成界面历史数组；仅在需要展示时调用，以减少后台数组分配。
    public func snapshot(
        endingAt now: ContinuousClock.Instant,
        window: HistoryWindow
    ) -> DashboardHistory {
        DashboardHistory(
            cpuUsage: trimmed(cpu.elements(), endingAt: now, window: window),
            memoryUsage: trimmed(memory.elements(), endingAt: now, window: window),
            diskRead: trimmed(diskRead.elements(), endingAt: now, window: window),
            diskWrite: trimmed(diskWrite.elements(), endingAt: now, window: window),
            networkDownload: trimmed(networkDownload.elements(), endingAt: now, window: window),
            networkUpload: trimmed(networkUpload.elements(), endingAt: now, window: window)
        )
    }

    private func point(_ value: Double, from snapshot: SystemSnapshot) -> HistoryPoint {
        HistoryPoint(
            sequence: snapshot.sequence,
            wallTime: snapshot.wallTime,
            monotonicTime: snapshot.monotonicTime,
            value: value
        )
    }

    /// 使用单调时钟筛选窗口内的点，避免系统日期调整影响历史过期判断。
    private func trimmed(
        _ values: [HistoryPoint],
        endingAt now: ContinuousClock.Instant,
        window: HistoryWindow
    ) -> [HistoryPoint] {
        values.filter { point in
            point.monotonicTime.duration(to: now) <= window.duration
        }
    }
}
