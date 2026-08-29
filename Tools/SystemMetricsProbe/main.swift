import Foundation
import PulseBarCore

@main
struct SystemMetricsProbe {
    static func main() async {
        print("PulseBar System Metrics Probe")
        print("architecture: \(architecture)")
        print("os: \(ProcessInfo.processInfo.operatingSystemVersionString)")

        timedProbe("CPU ticks") {
            let ticks = try MachCPURawReader().readTicks()
            return "\(ticks.count) logical processors"
        }

        timedProbe("VM statistics") {
            let stats = try MachMemoryRawReader().readVMStatistics()
            return "pageSize=\(stats.pageSize), activePages=\(stats.activePages)"
        }

        timedProbe("Swap") {
            let swap = try MachMemoryRawReader().readSwapUsage()
            return "used=\(swap?.usedBytes ?? 0), total=\(swap?.totalBytes ?? 0)"
        }

        timedProbe("Network counters") {
            let counters = try BSDInterfaceCounterReader().readInterfaceCounters()
            let primary = SystemPrimaryInterfaceResolver().primaryInterfaceName() ?? "none"
            return "\(counters.count) interfaces, primary=\(primary)"
        }

        timedProbe("Volume capacity") {
            let volumes = try VolumeCapacityRawReader().readVolumes()
            return "\(volumes.count) local volumes"
        }

        timedProbe("Disk I/O") {
            let counters = try IOKitDiskRawReader().readDeviceCounters()
            return "\(counters.count) block storage counters"
        }

        await probeDeltas()
    }

    private static func timedProbe(_ name: String, operation: () throws -> String) {
        let clock = ContinuousClock()
        let started = clock.now
        do {
            let detail = try operation()
            let milliseconds = started.duration(to: clock.now).milliseconds
            print("PASS \(name): \(detail), \(format(milliseconds)) ms")
        } catch {
            print("DEGRADED \(name): \(error)")
        }
    }

    private static func probeDeltas() async {
        let cpuReader = MachCPURawReader()
        let diskReader = IOKitDiskRawReader()
        let networkReader = BSDInterfaceCounterReader()
        let interfaceName = SystemPrimaryInterfaceResolver().primaryInterfaceName()
        let clock = ContinuousClock()

        guard let firstCPU = try? cpuReader.readTicks(),
              let firstDisk = try? diskReader.readDeviceCounters(),
              let firstNetwork = try? networkReader.readInterfaceCounters() else {
            print("DEGRADED one-second delta: baseline unavailable")
            return
        }
        let started = clock.now
        try? await Task.sleep(for: .seconds(1))
        let elapsed = started.duration(to: clock.now).seconds

        guard let secondCPU = try? cpuReader.readTicks(),
              let secondDisk = try? diskReader.readDeviceCounters(),
              let secondNetwork = try? networkReader.readInterfaceCounters(),
              elapsed > 0 else {
            print("DEGRADED one-second delta: second sample unavailable")
            return
        }

        let cpu = cpuUsage(previous: firstCPU, current: secondCPU)
        let disk = aggregateDelta(previous: firstDisk, current: secondDisk)
        let network = networkDelta(
            interfaceName: interfaceName,
            previous: firstNetwork,
            current: secondNetwork
        )
        print(
            "PASS one-second delta: cpu=\(format((cpu ?? 0) * 100))%, " +
            "disk read=\(format(Double(disk.read) / elapsed)) B/s, " +
            "write=\(format(Double(disk.write) / elapsed)) B/s, " +
            "network down=\(format(Double(network.received) / elapsed)) B/s, " +
            "up=\(format(Double(network.sent) / elapsed)) B/s"
        )
    }

    private static func cpuUsage(
        previous: [CPUTickCounter],
        current: [CPUTickCounter]
    ) -> Double? {
        guard previous.count == current.count else { return nil }
        var active: UInt64 = 0
        var total: UInt64 = 0
        for (old, new) in zip(previous, current) {
            guard new.user >= old.user,
                  new.system >= old.system,
                  new.nice >= old.nice,
                  new.idle >= old.idle else { return nil }
            let user = new.user - old.user
            let system = new.system - old.system
            let nice = new.nice - old.nice
            let idle = new.idle - old.idle
            active += user + system + nice
            total += user + system + nice + idle
        }
        guard total > 0 else { return nil }
        return min(1, max(0, Double(active) / Double(total)))
    }

    private static func aggregateDelta(
        previous: [DiskDeviceCounter],
        current: [DiskDeviceCounter]
    ) -> (read: UInt64, write: UInt64) {
        let oldByID = Dictionary(uniqueKeysWithValues: previous.map { ($0.id, $0) })
        return current.reduce(into: (read: UInt64(0), write: UInt64(0))) { result, value in
            guard let old = oldByID[value.id],
                  value.readBytes >= old.readBytes,
                  value.writtenBytes >= old.writtenBytes else { return }
            result.read += value.readBytes - old.readBytes
            result.write += value.writtenBytes - old.writtenBytes
        }
    }

    private static func networkDelta(
        interfaceName: String?,
        previous: [InterfaceCounter],
        current: [InterfaceCounter]
    ) -> (received: UInt64, sent: UInt64) {
        guard let interfaceName,
              let old = previous.first(where: { $0.name == interfaceName }),
              let new = current.first(where: { $0.name == interfaceName }),
              new.receivedBytes >= old.receivedBytes,
              new.sentBytes >= old.sentBytes else {
            return (0, 0)
        }
        return (new.receivedBytes - old.receivedBytes, new.sentBytes - old.sentBytes)
    }

    private static func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(2)))
    }

    private static var architecture: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }
}

private extension Duration {
    var seconds: Double {
        let parts = components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }

    var milliseconds: Double {
        seconds * 1_000
    }
}
