import Foundation
import os
@testable import PulseBarCore

final class SequenceCPUReader: CPURawReading, Sendable {
    private let samples: OSAllocatedUnfairLock<[[CPUTickCounter]]>

    init(_ samples: [[CPUTickCounter]]) {
        self.samples = OSAllocatedUnfairLock(initialState: samples)
    }

    func readTicks() throws -> [CPUTickCounter] {
        samples.withLock { values in
            values.isEmpty ? [] : values.removeFirst()
        }
    }
}

struct FixedMemoryReader: MemoryRawReading {
    let statistics: RawVMStatistics
    let swap: RawSwapUsage?

    func readVMStatistics() throws -> RawVMStatistics { statistics }
    func readSwapUsage() throws -> RawSwapUsage? { swap }
}

struct FixedPressureReader: MemoryPressureReading {
    let pressure: MemoryPressureState
    func currentPressure() async -> MemoryPressureState { pressure }
}

final class SequenceDiskReader: DiskRawReading, Sendable {
    private let samples: OSAllocatedUnfairLock<[[DiskDeviceCounter]]>

    init(_ samples: [[DiskDeviceCounter]]) {
        self.samples = OSAllocatedUnfairLock(initialState: samples)
    }

    func readDeviceCounters() throws -> [DiskDeviceCounter] {
        samples.withLock { values in
            values.isEmpty ? [] : values.removeFirst()
        }
    }
}

struct FailingDiskReader: DiskRawReading {
    func readDeviceCounters() throws -> [DiskDeviceCounter] {
        throw SystemMetricReadError.sourceUnavailable("test disk")
    }
}

struct FixedVolumeReader: VolumeRawReading {
    let volumes: [RawVolumeCapacity]
    func readVolumes() throws -> [RawVolumeCapacity] { volumes }
}

final class SequenceNetworkReader: NetworkRawReading, Sendable {
    private let samples: OSAllocatedUnfairLock<[[InterfaceCounter]]>

    init(_ samples: [[InterfaceCounter]]) {
        self.samples = OSAllocatedUnfairLock(initialState: samples)
    }

    func readInterfaceCounters() throws -> [InterfaceCounter] {
        samples.withLock { values in
            values.isEmpty ? [] : values.removeFirst()
        }
    }
}

struct FixedInterfaceResolver: PrimaryInterfaceResolving {
    let name: String?
    func primaryInterfaceName() -> String? { name }
}

struct FixedPathReader: NetworkPathReading {
    let path: NetworkPathState
    func currentPath() async -> NetworkPathState { path }
}

func tick(_ user: UInt64, _ system: UInt64, _ nice: UInt64, _ idle: UInt64) -> CPUTickCounter {
    CPUTickCounter(user: user, system: system, nice: nice, idle: idle)
}

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
