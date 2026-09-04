import Foundation

public struct SystemSnapshot: Sendable, Equatable {
    public let sequence: UInt64
    public let wallTime: Date
    public let monotonicTime: ContinuousClock.Instant
    public let cpu: MetricValue<CPUSnapshot>
    public let memory: MetricValue<MemorySnapshot>
    public let disk: MetricValue<DiskSnapshot>
    public let network: MetricValue<NetworkSnapshot>

    /// 把同轮采样的四类指标封装为不可变快照。
    /// wallTime 用于展示，monotonicTime 用于间隔和过期计算，sequence 用于跨序列对齐。
    public init(
        sequence: UInt64,
        wallTime: Date,
        monotonicTime: ContinuousClock.Instant,
        cpu: MetricValue<CPUSnapshot>,
        memory: MetricValue<MemorySnapshot>,
        disk: MetricValue<DiskSnapshot>,
        network: MetricValue<NetworkSnapshot>
    ) {
        self.sequence = sequence
        self.wallTime = wallTime
        self.monotonicTime = monotonicTime
        self.cpu = cpu
        self.memory = memory
        self.disk = disk
        self.network = network
    }
}

public struct CPUSnapshot: Sendable, Equatable {
    public let totalUsageRatio: Double
    public let userUsageRatio: Double
    public let systemUsageRatio: Double
    public let niceUsageRatio: Double
    public let idleUsageRatio: Double
    public let perCoreUsageRatios: [Double]
    public let loadAverage1m: Double?
    public let loadAverage5m: Double?
    public let loadAverage15m: Double?
}

public struct MemorySnapshot: Sendable, Equatable {
    public let physicalTotalBytes: UInt64
    public let usedApproximationBytes: UInt64
    public let availableApproximationBytes: UInt64
    public let freeBytes: UInt64
    public let activeBytes: UInt64
    public let inactiveBytes: UInt64
    public let speculativeBytes: UInt64
    public let wiredBytes: UInt64
    public let compressedBytes: UInt64
    public let purgeableBytes: UInt64
    public let swapUsedBytes: UInt64?
    public let swapTotalBytes: UInt64?
    public let pressure: MemoryPressureState

    public var usageRatio: Double {
        guard physicalTotalBytes > 0 else { return 0 }
        return min(1, max(0, Double(usedApproximationBytes) / Double(physicalTotalBytes)))
    }
}

public enum MemoryPressureState: String, Sendable, Equatable {
    case normal
    case warning
    case critical
    case unknown
}

public struct DiskSnapshot: Sendable, Equatable {
    public let primaryVolumeID: String?
    public let volumes: [VolumeSnapshot]
    public let aggregateReadBytesPerSecond: Double?
    public let aggregateWriteBytesPerSecond: Double?
    public let ioState: RateMetricState

    public var primaryVolume: VolumeSnapshot? {
        guard let primaryVolumeID else { return volumes.first }
        return volumes.first { $0.id == primaryVolumeID }
    }
}

public struct VolumeSnapshot: Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let mountPathDisplayName: String
    public let totalCapacityBytes: UInt64
    public let availableCapacityBytes: UInt64
    public let isInternal: Bool?
    public let isLocal: Bool?
    public let isRemovable: Bool?

    public var usedCapacityBytes: UInt64 {
        totalCapacityBytes - min(totalCapacityBytes, availableCapacityBytes)
    }

    public var usageRatio: Double {
        guard totalCapacityBytes > 0 else { return 0 }
        return Double(usedCapacityBytes) / Double(totalCapacityBytes)
    }
}

public enum RateMetricState: Sendable, Equatable {
    case available
    case warmingUp
    case unavailable(MetricFailure)
}

public struct NetworkSnapshot: Sendable, Equatable {
    public let pathStatus: NetworkPathStatus
    public let interface: NetworkInterfaceSnapshot?
    public let downloadBytesPerSecond: Double?
    public let uploadBytesPerSecond: Double?
    public let sessionDownloadedBytes: UInt64
    public let sessionUploadedBytes: UInt64
    public let localAddresses: [String]
    public let rateState: RateMetricState
}

public struct NetworkInterfaceSnapshot: Sendable, Equatable {
    public let name: String
    public let kind: NetworkInterfaceKind
    public let receivedBytes: UInt64
    public let sentBytes: UInt64
}

public enum NetworkPathStatus: String, Sendable, Equatable {
    case online
    case offline
    case requiresConnection
    case unknown
}

public enum NetworkInterfaceKind: String, Sendable, Equatable {
    case wifi
    case ethernet
    case vpn
    case cellular
    case wired
    case other
    case unknown
}
