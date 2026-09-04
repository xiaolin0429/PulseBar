import Foundation
import os
@testable import PulseBarCore

final class SequenceCPUReader: CPURawReading, Sendable {
    private let samples: OSAllocatedUnfairLock<[[CPUTickCounter]]>

    /// 用带锁队列保存预设 CPU 计数序列，允许采集器在并发环境中安全取样。
    init(_ samples: [[CPUTickCounter]]) {
        self.samples = OSAllocatedUnfairLock(initialState: samples)
    }

    /// 依次消费一帧 CPU 计数；序列耗尽时返回空数组。
    func readTicks() throws -> [CPUTickCounter] {
        samples.withLock { values in
            values.isEmpty ? [] : values.removeFirst()
        }
    }
}

struct FixedMemoryReader: MemoryRawReading {
    let statistics: RawVMStatistics
    let swap: RawSwapUsage?

    /// 返回固定 VM 计数，供内存公式测试使用。
    func readVMStatistics() throws -> RawVMStatistics { statistics }
    /// 返回固定交换空间结果，包括用于模拟缺失的 nil。
    func readSwapUsage() throws -> RawSwapUsage? { swap }
}

struct FixedPressureReader: MemoryPressureReading {
    let pressure: MemoryPressureState
    /// 返回预设压力状态，不启动系统事件监听。
    func currentPressure() async -> MemoryPressureState { pressure }
}

final class SequenceDiskReader: DiskRawReading, Sendable {
    private let samples: OSAllocatedUnfairLock<[[DiskDeviceCounter]]>

    /// 用带锁队列保存设备计数序列，供跨帧读写差分测试使用。
    init(_ samples: [[DiskDeviceCounter]]) {
        self.samples = OSAllocatedUnfairLock(initialState: samples)
    }

    /// 依次消费一帧设备计数；序列耗尽时返回空数组。
    func readDeviceCounters() throws -> [DiskDeviceCounter] {
        samples.withLock { values in
            values.isEmpty ? [] : values.removeFirst()
        }
    }
}

struct FailingDiskReader: DiskRawReading {
    /// 始终抛出磁盘来源不可用错误，用于验证容量与 I/O 独立降级。
    func readDeviceCounters() throws -> [DiskDeviceCounter] {
        throw SystemMetricReadError.sourceUnavailable("test disk")
    }
}

struct FixedVolumeReader: VolumeRawReading {
    let volumes: [RawVolumeCapacity]
    /// 返回预设卷列表，避免测试枚举真实文件系统。
    func readVolumes() throws -> [RawVolumeCapacity] { volumes }
}

final class SequenceNetworkReader: NetworkRawReading, Sendable {
    private let samples: OSAllocatedUnfairLock<[[InterfaceCounter]]>

    /// 用带锁队列保存接口计数序列，模拟流量变化或接口切换。
    init(_ samples: [[InterfaceCounter]]) {
        self.samples = OSAllocatedUnfairLock(initialState: samples)
    }

    /// 依次消费一帧接口计数；序列耗尽时返回空数组。
    func readInterfaceCounters() throws -> [InterfaceCounter] {
        samples.withLock { values in
            values.isEmpty ? [] : values.removeFirst()
        }
    }
}

struct FixedInterfaceResolver: PrimaryInterfaceResolving {
    let name: String?
    /// 返回指定主接口名；nil 用于触发采集器的回退选择。
    func primaryInterfaceName() -> String? { name }
}

struct FixedPathReader: NetworkPathReading {
    let path: NetworkPathState
    /// 返回固定网络路径，不启动真实网络监听。
    func currentPath() async -> NetworkPathState { path }
}

/// 用简短参数构造 CPU 累计 ticks，突出测试中的跨帧差值。
func tick(_ user: UInt64, _ system: UInt64, _ nice: UInt64, _ idle: UInt64) -> CPUTickCounter {
    CPUTickCounter(user: user, system: system, nice: nice, idle: idle)
}

/// 构造默认已启用、运行中的接口计数，可选标记为回环接口。
func interface(
    _ name: String,
    received: UInt64,
    sent: UInt64,
    loopback: Bool = false
) -> InterfaceCounter {
    InterfaceCounter(
        name: name,
        receivedBytes: received,
        sentBytes: sent,
        isUp: true,
        isRunning: true,
        isLoopback: loopback
    )
}

let testVolume = RawVolumeCapacity(
    id: "root",
    name: "Macintosh HD",
    mountPath: "/",
    totalBytes: 1_000,
    availableBytes: 400,
    isLocal: true,
    isInternal: true,
    isRemovable: false
)
