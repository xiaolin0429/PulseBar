import Foundation

public struct SnapshotNormalizer: Sendable {
    private var lastCPU: TimedValue<CPUSnapshot>?
    private var lastMemory: TimedValue<MemorySnapshot>?
    private var lastDisk: TimedValue<DiskSnapshot>?
    private var lastNetwork: TimedValue<NetworkSnapshot>?

    public init() {}

    public mutating func normalize(_ snapshot: SystemSnapshot) -> SystemSnapshot {
        SystemSnapshot(
            sequence: snapshot.sequence,
            wallTime: snapshot.wallTime,
            monotonicTime: snapshot.monotonicTime,
            cpu: normalize(snapshot.cpu, at: snapshot.monotonicTime, previous: &lastCPU),
            memory: normalize(snapshot.memory, at: snapshot.monotonicTime, previous: &lastMemory),
            disk: normalize(snapshot.disk, at: snapshot.monotonicTime, previous: &lastDisk),
            network: normalize(snapshot.network, at: snapshot.monotonicTime, previous: &lastNetwork)
        )
    }

    public mutating func reset() {
        lastCPU = nil
        lastMemory = nil
        lastDisk = nil
        lastNetwork = nil
    }

    /// 缓存成功值；读取失败时仅用 30 秒内的成功值降级为 stale，超时保持不可用。
    /// 预热状态原样返回；传入 stale 时只按已有缓存时间更新年龄。
    private func normalize<Value>(
        _ current: MetricValue<Value>,
        at instant: ContinuousClock.Instant,
        previous: inout TimedValue<Value>?
    ) -> MetricValue<Value> where Value: Sendable & Equatable {
        switch current {
        case let .available(value):
            previous = TimedValue(value: value, instant: instant)
            return current
        case .warmingUp:
            return .warmingUp
        case let .unavailable(failure):
            guard let previous else { return .unavailable(failure) }
            let age = previous.instant.duration(to: instant)
            guard age <= .seconds(30) else { return .unavailable(failure) }
            return .stale(previous.value, age: age)
        case let .stale(value, _):
            guard let previous else { return current }
            return .stale(value, age: previous.instant.duration(to: instant))
        }
    }
}

private struct TimedValue<Value: Sendable & Equatable>: Sendable {
    let value: Value
    let instant: ContinuousClock.Instant
}
