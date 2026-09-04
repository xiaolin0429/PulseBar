import Foundation

public actor DiskCollector {
    private let counterReader: any DiskRawReading
    private let volumeReader: any VolumeRawReading
    private var previousCounters: [UInt64: DiskDeviceCounter]?
    private var previousInstant: ContinuousClock.Instant?
    private var cachedVolumes: [RawVolumeCapacity] = []
    private var lastVolumeRead: ContinuousClock.Instant?

    /// 分别注入块设备计数器和卷容量读取器，使速率与容量可以独立降级。
    public init(
        counterReader: any DiskRawReading = IOKitDiskRawReader(),
        volumeReader: any VolumeRawReading = VolumeCapacityRawReader()
    ) {
        self.counterReader = counterReader
        self.volumeReader = volumeReader
    }

    /// 读取卷容量，并用块设备累计读写字节差除以实际单调时钟间隔计算 B/s。
    /// 容量最多每 10 秒刷新一次；I/O 读取失败仍保留容量展示，有旧容量缓存时允许继续使用。
    public func sample(at instant: ContinuousClock.Instant) -> MetricValue<DiskSnapshot> {
        if shouldRefreshVolumes(at: instant) {
            do {
                cachedVolumes = try volumeReader.readVolumes()
                lastVolumeRead = instant
            } catch where !cachedVolumes.isEmpty {
                lastVolumeRead = instant
            } catch {
                return .unavailable(.reading(error, source: "Disk capacity"))
            }
        }

        guard !cachedVolumes.isEmpty else {
            return .unavailable(
                MetricFailure(
                    code: .sourceMissing,
                    userMessageKey: "metric.disk.capacityUnavailable"
                )
            )
        }

        let volumes = cachedVolumes.map {
            VolumeSnapshot(
                id: $0.id,
                name: $0.name,
                mountPathDisplayName: $0.mountPath,
                totalCapacityBytes: $0.totalBytes,
                availableCapacityBytes: $0.availableBytes,
                isInternal: $0.isInternal,
                isLocal: $0.isLocal,
                isRemovable: $0.isRemovable
            )
        }
        let primaryVolumeID = cachedVolumes.first(where: { $0.mountPath == "/" })?.id
            ?? cachedVolumes.first(where: { $0.isInternal == true })?.id
            ?? cachedVolumes.first?.id

        do {
            let current = deduplicated(try counterReader.readDeviceCounters())
            defer {
                previousCounters = current
                previousInstant = instant
            }
            guard let previousCounters,
                  let previousInstant,
                  !current.isEmpty else {
                return .available(
                    snapshot(volumes: volumes, primaryVolumeID: primaryVolumeID, state: .warmingUp)
                )
            }
            let elapsed = previousInstant.duration(to: instant).secondsValue
            guard elapsed > 0,
                  let deltas = aggregateDeltas(previous: previousCounters, current: current) else {
                return .available(
                    snapshot(volumes: volumes, primaryVolumeID: primaryVolumeID, state: .warmingUp)
                )
            }
            return .available(
                DiskSnapshot(
                    primaryVolumeID: primaryVolumeID,
                    volumes: volumes,
                    aggregateReadBytesPerSecond: Double(deltas.read) / elapsed,
                    aggregateWriteBytesPerSecond: Double(deltas.write) / elapsed,
                    ioState: .available
                )
            )
        } catch {
            previousCounters = nil
            previousInstant = nil
            return .available(
                snapshot(
                    volumes: volumes,
                    primaryVolumeID: primaryVolumeID,
                    state: .unavailable(.reading(error, source: "Disk I/O"))
                )
            )
        }
    }

    /// 清除读写计数与时间基线；不清除低频刷新使用的卷容量缓存。
    public func resetBaseline() {
        previousCounters = nil
        previousInstant = nil
    }

    /// 标记卷列表过期，在下一次采样时重新枚举挂载卷。
    public func invalidateVolumes() {
        lastVolumeRead = nil
    }

    /// 首次读取或距上次刷新满 10 秒时才刷新，避免每帧枚举卷带来的开销。
    private func shouldRefreshVolumes(at instant: ContinuousClock.Instant) -> Bool {
        guard let lastVolumeRead else { return true }
        return lastVolumeRead.duration(to: instant) >= .seconds(10)
    }

    /// 按 IOKit 注册表 ID 去重，同一设备保留最后一个计数。
    private func deduplicated(_ values: [DiskDeviceCounter]) -> [UInt64: DiskDeviceCounter] {
        values.reduce(into: [:]) { result, value in result[value.id] = value }
    }

    /// 只累加两帧中都存在的设备差值，新增设备先不参与计算。
    /// 任一计数回退、累加溢出或没有可匹配设备时返回 nil，交由调用方预热。
    private func aggregateDeltas(
        previous: [UInt64: DiskDeviceCounter],
        current: [UInt64: DiskDeviceCounter]
    ) -> (read: UInt64, write: UInt64)? {
        var read: UInt64 = 0
        var write: UInt64 = 0
        var matched = false
        for (id, value) in current {
            guard let old = previous[id] else { continue }
            guard value.readBytes >= old.readBytes,
                  value.writtenBytes >= old.writtenBytes else {
                return nil
            }
            matched = true
            let readResult = read.addingReportingOverflow(value.readBytes - old.readBytes)
            let writeResult = write.addingReportingOverflow(value.writtenBytes - old.writtenBytes)
            guard !readResult.overflow, !writeResult.overflow else { return nil }
            read = readResult.partialValue
            write = writeResult.partialValue
        }
        return matched ? (read, write) : nil
    }

    /// 构造仅有容量和 I/O 状态的快照；速率留空，以区别于真实的零吞吐。
    private func snapshot(
        volumes: [VolumeSnapshot],
        primaryVolumeID: String?,
        state: RateMetricState
    ) -> DiskSnapshot {
        DiskSnapshot(
            primaryVolumeID: primaryVolumeID,
            volumes: volumes,
            aggregateReadBytesPerSecond: nil,
            aggregateWriteBytesPerSecond: nil,
            ioState: state
        )
    }
}
